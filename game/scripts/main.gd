extends Node2D

@onready var atlas_api: HTTPRequest = $AtlasAPI

const CHAT_URL := "http://127.0.0.1:8000/chat"


func _ready():
	atlas_api.request_completed.connect(_on_atlas_api_request_completed)

	print("Find Hope iniciado.")
	print("Testando conexão com Atlas Core...")

	send_message_to_atlas("Atlas, consegues ouvir-me?")


func send_message_to_atlas(message: String):
	var headers = [
		"Content-Type: application/json"
	]

	var body = JSON.stringify({
		"message": message
	})

	var error = atlas_api.request(
		CHAT_URL,
		headers,
		HTTPClient.METHOD_POST,
		body
	)

	if error != OK:
		print("Erro ao enviar mensagem para Atlas: ", error)


func _on_atlas_api_request_completed(
	result,
	response_code,
	headers,
	body
):
	print("")
	print("========== ATLAS CORE ==========")
	print("HTTP: ", response_code)

	if response_code != 200:
		print("Erro recebido do backend.")
		print(body.get_string_from_utf8())
		return

	var text = body.get_string_from_utf8()
	var data = JSON.parse_string(text)

	if data == null:
		print("Resposta JSON inválida:")
		print(text)
		return

	print("Mensagem enviada:")
	print("Atlas, consegues ouvir-me?")

	print("")
	print("Resposta do Atlas:")
	print(data.get("response", "Sem resposta."))

	print("================================")
