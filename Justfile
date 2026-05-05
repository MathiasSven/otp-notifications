[arg("sign", short="s", long="sign", value="true")]
[arg("debug", short="d", long="debug", value="true")]
compile sign="false" debug="false":
	cherri ./main.cherri --derive-uuids \
		{{ if sign == "true" { "" } else { "--skip-sign" } }} \
		{{ if debug == "true" { "--debug" } else { "" } }}

[no-cd]
quick-upload file:
	@curl -sS uploader.sh -T "{{file}}" \
		| awk '/^wget / {print $2 "?download=1"}' \
		| tee /dev/stderr | qrencode -t ansiutf8

send-message port="8429":
	@curl -X POST http://127.0.0.1:{{port}}/ \
		-H 'Content-Type: application/json' \
		-d '{"sender":"Test","code":"1234","content":"Your OTP is 1234"}'
