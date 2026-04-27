"""
Tiny GPT trainer plus JSON exporter for Godot inference.
"""

import json
import math
import os
import random
from typing import Dict, List, Sequence, Tuple

random.seed(42)


class Value:
    """Scalar value node with autograd."""

    __slots__ = ("data", "grad", "_children", "_local_grads")

    def __init__(
        self,
        data: float,
        children: Tuple["Value", ...] = (),
        local_grads: Tuple[float, ...] = (),
    ) -> None:
        self.data = data
        self.grad = 0.0
        self._children = children
        self._local_grads = local_grads

    def __add__(self, other: "Value | float") -> "Value":
        other = other if isinstance(other, Value) else Value(float(other))
        return Value(self.data + other.data, (self, other), (1.0, 1.0))

    def __mul__(self, other: "Value | float") -> "Value":
        other = other if isinstance(other, Value) else Value(float(other))
        return Value(self.data * other.data, (self, other), (other.data, self.data))

    def __pow__(self, power: float) -> "Value":
        return Value(self.data**power, (self,), (power * self.data ** (power - 1.0),))

    def log(self) -> "Value":
        return Value(math.log(self.data), (self,), (1.0 / self.data,))

    def exp(self) -> "Value":
        out = math.exp(self.data)
        return Value(out, (self,), (out,))

    def relu(self) -> "Value":
        return Value(max(0.0, self.data), (self,), (float(self.data > 0.0),))

    def __neg__(self) -> "Value":
        return self * -1.0

    def __radd__(self, other: "Value | float") -> "Value":
        return self + other

    def __sub__(self, other: "Value | float") -> "Value":
        return self + (-other)

    def __rsub__(self, other: "Value | float") -> "Value":
        return other + (-self)

    def __rmul__(self, other: "Value | float") -> "Value":
        return self * other

    def __truediv__(self, other: float) -> "Value":
        return self * (other**-1.0)

    def __rtruediv__(self, other: "Value | float") -> "Value":
        return other * (self**-1.0)

    def backward(self) -> None:
        """Backpropagate gradients from this node."""
        topo: List[Value] = []
        visited: set[Value] = set()

        def build_topo(v: Value) -> None:
            if v not in visited:
                visited.add(v)
                for child in v._children:
                    build_topo(child)
                topo.append(v)

        build_topo(self)
        self.grad = 1.0
        for v in reversed(topo):
            for child, local_grad in zip(v._children, v._local_grads):
                child.grad += local_grad * v.grad


def matrix(nout: int, nin: int, std: float = 0.08) -> List[List[Value]]:
    """Create random weight matrix."""
    return [[Value(random.gauss(0.0, std)) for _ in range(nin)] for _ in range(nout)]


def linear(x: Sequence[Value], w: Sequence[Sequence[Value]]) -> List[Value]:
    """Apply linear transform W @ x."""
    return [sum(wi * xi for wi, xi in zip(wo, x)) for wo in w]


def softmax(logits: Sequence[Value]) -> List[Value]:
    """Compute stable softmax over Value logits."""
    max_val = max(v.data for v in logits)
    exps = [(v - max_val).exp() for v in logits]
    total = sum(exps)
    return [e / total for e in exps]


def rmsnorm(x: Sequence[Value]) -> List[Value]:
    """Apply RMSNorm."""
    ms = sum(xi * xi for xi in x) / len(x)
    scale = (ms + 1e-5) ** -0.5
    return [xi * scale for xi in x]


def gpt(
    token_id: int,
    pos_id: int,
    keys: List[List[List[Value]]],
    values: List[List[List[Value]]],
    state_dict: Dict[str, List[List[Value]]],
    n_layer: int,
    n_head: int,
    head_dim: int,
) -> List[Value]:
    """Forward one token step."""
    tok_emb = state_dict["wte"][token_id]
    pos_emb = state_dict["wpe"][pos_id]
    x = [t + p for t, p in zip(tok_emb, pos_emb)]
    x = rmsnorm(x)

    for li in range(n_layer):
        x_residual = x
        x = rmsnorm(x)
        q = linear(x, state_dict[f"layer{li}.attn_wq"])
        k = linear(x, state_dict[f"layer{li}.attn_wk"])
        v = linear(x, state_dict[f"layer{li}.attn_wv"])
        keys[li].append(k)
        values[li].append(v)

        x_attn: List[Value] = []
        for h in range(n_head):
            hs = h * head_dim
            q_h = q[hs : hs + head_dim]
            k_h = [ki[hs : hs + head_dim] for ki in keys[li]]
            v_h = [vi[hs : hs + head_dim] for vi in values[li]]
            attn_logits = [
                sum(q_h[j] * k_h[t][j] for j in range(head_dim)) / (head_dim**0.5)
                for t in range(len(k_h))
            ]
            attn_weights = softmax(attn_logits)
            head_out = [
                sum(attn_weights[t] * v_h[t][j] for t in range(len(v_h)))
                for j in range(head_dim)
            ]
            x_attn.extend(head_out)
        x = linear(x_attn, state_dict[f"layer{li}.attn_wo"])
        x = [a + b for a, b in zip(x, x_residual)]

        x_residual = x
        x = rmsnorm(x)
        x = linear(x, state_dict[f"layer{li}.mlp_fc1"])
        x = [xi.relu() for xi in x]
        x = linear(x, state_dict[f"layer{li}.mlp_fc2"])
        x = [a + b for a, b in zip(x, x_residual)]

    return linear(x, state_dict["lm_head"])


def export_weights(
    output_path: str,
    state_dict: Dict[str, List[List[Value]]],
    uchars: List[str],
    bos_token_id: int,
    config: Dict[str, int],
) -> None:
    """Write trained model to JSON.

    Args:
        output_path: Destination JSON path.
        state_dict: Trained parameters.
        uchars: Character list without BOS.
        bos_token_id: Special BOS token id.
        config: Model config.
    """
    payload = {
        "format_version": 1,
        "tokenizer": {
            "chars": uchars,
            "bos_token_id": bos_token_id,
            "vocab_size": len(uchars) + 1,
        },
        "config": config,
        "weights": {
            key: [[v.data for v in row] for row in mat]
            for key, mat in state_dict.items()
        },
    }
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(payload, f)


def main() -> None:
    """Train tiny model and export weights JSON."""
    input_path = "brainrot_words.txt"
    output_path = "microgpt_weights.json"
    
    docs = [line.strip() for line in open(input_path, encoding="utf-8") if line.strip()]
    random.shuffle(docs)
    print(f"num docs: {len(docs)}")

    uchars = sorted(set("".join(docs)))
    bos_token_id = len(uchars)
    vocab_size = len(uchars) + 1
    print(f"vocab size: {vocab_size}")

    n_layer = 2
    n_embd = 16
    block_size = 20
    n_head = 4
    head_dim = n_embd // n_head

    state_dict: Dict[str, List[List[Value]]] = {
        "wte": matrix(vocab_size, n_embd),
        "wpe": matrix(block_size, n_embd),
        "lm_head": matrix(vocab_size, n_embd),
    }
    for i in range(n_layer):
        state_dict[f"layer{i}.attn_wq"] = matrix(n_embd, n_embd)
        state_dict[f"layer{i}.attn_wk"] = matrix(n_embd, n_embd)
        state_dict[f"layer{i}.attn_wv"] = matrix(n_embd, n_embd)
        state_dict[f"layer{i}.attn_wo"] = matrix(n_embd, n_embd)
        state_dict[f"layer{i}.mlp_fc1"] = matrix(4 * n_embd, n_embd)
        state_dict[f"layer{i}.mlp_fc2"] = matrix(n_embd, 4 * n_embd)

    params = [p for mat in state_dict.values() for row in mat for p in row]
    print(f"num params: {len(params)}")

    learning_rate, beta1, beta2, eps_adam = 0.01, 0.85, 0.99, 1e-8
    m = [0.0] * len(params)
    v = [0.0] * len(params)
    num_steps = 10000

    for step in range(num_steps):
        doc = docs[step % len(docs)]
        tokens = [bos_token_id] + [uchars.index(ch) for ch in doc] + [bos_token_id]
        n = min(block_size, len(tokens) - 1)

        keys, values = [[] for _ in range(n_layer)], [[] for _ in range(n_layer)]
        losses: List[Value] = []
        for pos_id in range(n):
            token_id, target_id = tokens[pos_id], tokens[pos_id + 1]
            logits = gpt(
                token_id, pos_id, keys, values, state_dict, n_layer, n_head, head_dim
            )
            probs = softmax(logits)
            losses.append(-probs[target_id].log())
        loss = (1.0 / n) * sum(losses)

        loss.backward()
        lr_t = learning_rate * (1.0 - step / num_steps)
        for i, p in enumerate(params):
            m[i] = beta1 * m[i] + (1.0 - beta1) * p.grad
            v[i] = beta2 * v[i] + (1.0 - beta2) * p.grad**2
            m_hat = m[i] / (1.0 - beta1 ** (step + 1))
            v_hat = v[i] / (1.0 - beta2 ** (step + 1))
            p.data -= lr_t * m_hat / (v_hat**0.5 + eps_adam)
            p.grad = 0.0

        print(f"step {step + 1:4d}/{num_steps:4d} | loss {loss.data:.4f}", end="\r")

    print()
    export_weights(
        output_path=output_path,
        state_dict=state_dict,
        uchars=uchars,
        bos_token_id=bos_token_id,
        config={
            "n_layer": n_layer,
            "n_embd": n_embd,
            "block_size": block_size,
            "n_head": n_head,
            "head_dim": head_dim,
        },
    )
    print(f"exported weights: {output_path}")


if __name__ == "__main__":
    main()
