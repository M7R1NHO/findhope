
extends Node

const API_BASE_URL := "http://127.0.0.1:8000"
const REQUEST_TIMEOUT_SECONDS := 10.0


func export_state(run_id: String) -> Dictionary:
	if run_id.strip_edges().is_empty():
		return {"ok": false, "error": "run_id vazio"}

	var result := await _request_json(
		HTTPClient.METHOD_GET,
		"/atlas/run-state/" + run_id.uri_encode(),
		{}
	)

	if not result.get("ok", false):
		return result

	var payload: Dictionary = result.get("data", {})

	if (
		payload.get("status", "") != "ok"
		or not payload.get("state", {}) is Dictionary
	):
		return {
			"ok": false,
			"error": "Resposta inválida ao exportar estado de Atlas"
		}

	return {
		"ok": true,
		"state": payload["state"]
	}


func restore_state(
	run_id: String,
	state: Dictionary
) -> Dictionary:
	if run_id.strip_edges().is_empty():
		return {"ok": false, "error": "run_id vazio"}

	var result := await _request_json(
		HTTPClient.METHOD_PUT,
		"/atlas/run-state/" + run_id.uri_encode(),
		{
			"run_id": run_id,
			"state": state
		}
	)

	if not result.get("ok", false):
		return result

	var payload: Dictionary = result.get("data", {})

	if payload.get("status", "") != "ok":
		return {
			"ok": false,
			"error": str(
				payload.get(
					"message",
					"Falha ao restaurar estado de Atlas"
				)
			)
		}

	return {"ok": true}


func reset_state(run_id: String) -> Dictionary:
	if run_id.strip_edges().is_empty():
		return {"ok": false, "error": "run_id vazio"}

	var result := await _request_json(
		HTTPClient.METHOD_POST,
		"/atlas/run-state/" + run_id.uri_encode() + "/reset",
		{"run_id": run_id}
	)

	if not result.get("ok", false):
		return result

	var payload: Dictionary = result.get("data", {})

	if payload.get("status", "") != "ok":
		return {
			"ok": false,
			"error": str(
				payload.get(
					"message",
					"Falha ao reiniciar estado de Atlas"
				)
			)
		}

	return {"ok": true}


func _request_json(
	method: int,
	path: String,
	body: Dictionary
) -> Dictionary:
	var request := HTTPRequest.new()
	request.timeout = REQUEST_TIMEOUT_SECONDS
	add_child(request)

	var headers := PackedStringArray([
		"Content-Type: application/json"
	])

	var body_text := ""

	if method != HTTPClient.METHOD_GET:
		body_text = JSON.stringify(body)

	var request_error := request.request(
		API_BASE_URL + path,
		headers,
		method,
		body_text
	)

	if request_error != OK:
		request.queue_free()

		return {
			"ok": false,
			"error": (
				"Não foi possível iniciar o pedido HTTP: "
				+ str(request_error)
			)
		}

	var response: Array = await request.request_completed
	request.queue_free()

	var result_code: int = int(response[0])
	var response_code: int = int(response[1])
	var response_body: PackedByteArray = response[3]

	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false,
			"error": "Falha de ligação ao backend: " + str(result_code)
		}

	if response_code < 200 or response_code >= 300:
		return {
			"ok": false,
			"error": "Backend respondeu HTTP " + str(response_code)
		}

	var parsed = JSON.parse_string(
		response_body.get_string_from_utf8()
	)

	if not parsed is Dictionary:
		return {
			"ok": false,
			"error": "Resposta JSON inválida do backend"
		}

	return {
		"ok": true,
		"data": parsed
	}
