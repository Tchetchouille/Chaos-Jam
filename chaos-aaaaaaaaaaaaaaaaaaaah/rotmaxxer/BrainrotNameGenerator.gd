extends RefCounted
class_name BrainrotNameGenerator

var _loaded: bool = false
var _chars: Array = []
var _bos_token_id: int = -1
var _vocab_size: int = 0
var _config: Dictionary = {}
var _weights: Dictionary = {}


func load_model(weights_path: String) -> void:
	var file := FileAccess.open(weights_path, FileAccess.READ)
	if file == null:
		push_error("NounGenerator: could not open weights file: %s" % weights_path)
		_loaded = false
		return

	var text := file.get_as_text()
	file.close()

	var json := JSON.new()
	var err := json.parse(text)
	if err != OK:
		push_error("NounGenerator: invalid JSON in %s" % weights_path)
		_loaded = false
		return

	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		push_error("NounGenerator: root JSON must be a dictionary")
		_loaded = false
		return

	var tokenizer: Dictionary = data.get("tokenizer", {})
	_chars = tokenizer.get("chars", [])
	_bos_token_id = int(tokenizer.get("bos_token_id", -1))
	_vocab_size = int(tokenizer.get("vocab_size", 0))
	_config = data.get("config", {})
	_weights = data.get("weights", {})

	if _chars.is_empty() or _bos_token_id < 0 or _vocab_size <= 0:
		push_error("NounGenerator: missing tokenizer fields")
		_loaded = false
		return

	_loaded = true


func is_loaded() -> bool:
	return _loaded


func generate_noun(max_len: int = 16, temperature: float = 0.8, top_k: int = 12) -> String:
	if not _loaded:
		push_error("NounGenerator: call load_model() first")
		return ""

	temperature = max(0.001, temperature)
	max_len = max(1, max_len)

	var n_layer: int = int(_config.get("n_layer", 1))
	var block_size: int = int(_config.get("block_size", 16))
	var n_head: int = int(_config.get("n_head", 4))
	var head_dim: int = int(_config.get("head_dim", 4))

	var keys: Array = []
	var values: Array = []
	for _i in range(n_layer):
		keys.append([])
		values.append([])

	var token_id: int = _bos_token_id
	var out_chars: Array = []
	var limit: int = min(max_len, block_size)
	for pos_id in range(limit):
		var logits: Array = _gpt_step(token_id, pos_id, keys, values, n_layer, n_head, head_dim)
		var scaled: Array = []
		for l in logits:
			scaled.append(float(l) / temperature)
		var probs: Array = _softmax(scaled)
		probs = _top_k_probs(probs, top_k)
		token_id = _sample_index(probs)
		if token_id == _bos_token_id:
			break
		if token_id >= 0 and token_id < _chars.size():
			out_chars.append(_chars[token_id])
		else:
			break

	return "".join(PackedStringArray(out_chars))


func _gpt_step(
	token_id: int,
	pos_id: int,
	keys: Array,
	values: Array,
	n_layer: int,
	n_head: int,
	head_dim: int
) -> Array:
	var tok_emb: Array = _weights["wte"][token_id]
	var pos_emb: Array = _weights["wpe"][pos_id]
	var x: Array = _vec_add(tok_emb, pos_emb)
	x = _rmsnorm(x)

	for li in range(n_layer):
		var x_residual: Array = x
		x = _rmsnorm(x)
		var q: Array = _linear(x, _weights["layer%d.attn_wq" % li])
		var k: Array = _linear(x, _weights["layer%d.attn_wk" % li])
		var v: Array = _linear(x, _weights["layer%d.attn_wv" % li])
		keys[li].append(k)
		values[li].append(v)

		var x_attn: Array = []
		for h in range(n_head):
			var hs: int = h * head_dim
			var q_h: Array = q.slice(hs, hs + head_dim)
			var k_h: Array = []
			var v_h: Array = []
			for t in range(keys[li].size()):
				k_h.append(keys[li][t].slice(hs, hs + head_dim))
				v_h.append(values[li][t].slice(hs, hs + head_dim))

			var attn_logits: Array = []
			for t in range(k_h.size()):
				attn_logits.append(_dot(q_h, k_h[t]) / sqrt(float(head_dim)))
			var attn_weights: Array = _softmax(attn_logits)

			var head_out: Array = []
			for j in range(head_dim):
				var s := 0.0
				for t in range(v_h.size()):
					s += float(attn_weights[t]) * float(v_h[t][j])
				head_out.append(s)
			x_attn.append_array(head_out)

		x = _linear(x_attn, _weights["layer%d.attn_wo" % li])
		x = _vec_add(x, x_residual)

		x_residual = x
		x = _rmsnorm(x)
		x = _linear(x, _weights["layer%d.mlp_fc1" % li])
		x = _relu_vec(x)
		x = _linear(x, _weights["layer%d.mlp_fc2" % li])
		x = _vec_add(x, x_residual)

	return _linear(x, _weights["lm_head"])


func _linear(x: Array, w: Array) -> Array:
	var out: Array = []
	for row in w:
		var s := 0.0
		for i in range(x.size()):
			s += float(row[i]) * float(x[i])
		out.append(s)
	return out


func _softmax(logits: Array) -> Array:
	var max_val: float = -INF
	for v in logits:
		max_val = max(max_val, float(v))

	var exps: Array = []
	var total: float = 0.0
	for v in logits:
		var e: float = exp(float(v) - max_val)
		exps.append(e)
		total += e

	var probs: Array = []
	for e in exps:
		probs.append(float(e) / total)
	return probs


func _rmsnorm(x: Array) -> Array:
	var ms: float = 0.0
	for xi in x:
		var xf := float(xi)
		ms += xf * xf
	ms /= float(x.size())
	var scale: float = 1.0 / sqrt(ms + 1e-5)
	var out: Array = []
	for xi in x:
		out.append(float(xi) * scale)
	return out


func _relu_vec(x: Array) -> Array:
	var out: Array = []
	for xi in x:
		out.append(max(0.0, float(xi)))
	return out


func _vec_add(a: Array, b: Array) -> Array:
	var out: Array = []
	for i in range(a.size()):
		out.append(float(a[i]) + float(b[i]))
	return out


func _dot(a: Array, b: Array) -> float:
	var s := 0.0
	for i in range(a.size()):
		s += float(a[i]) * float(b[i])
	return s


func _sample_index(probs: Array) -> int:
	var r: float = randf()
	var cdf: float = 0.0
	for i in range(probs.size()):
		cdf += float(probs[i])
		if r <= cdf:
			return i
	return probs.size() - 1


func _top_k_probs(probs: Array, k: int) -> Array:
	var n: int = probs.size()
	if n == 0:
		return probs
	if k <= 0 or k >= n:
		return probs

	var indices: Array = []
	for i in range(n):
		indices.append(i)
	indices.sort_custom(func(a: int, b: int) -> bool: return float(probs[a]) > float(probs[b]))

	var out: Array = []
	out.resize(n)
	for i in range(n):
		out[i] = 0.0

	var total: float = 0.0
	for i in range(k):
		var idx: int = int(indices[i])
		total += float(probs[idx])

	if total <= 0.0:
		return probs

	for i in range(k):
		var idx: int = int(indices[i])
		out[idx] = float(probs[idx]) / total

	return out
