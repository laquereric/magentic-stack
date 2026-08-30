# The mandatory, distinct CPCP FRONT pod. No Rails: a thin JSON-RPC-LD client
# that talks to the Rails BACK over the wire.
# Index digest (multi-arch), not a platform digest -- same reference on arm64 and amd64.
FROM python:3.12-slim@sha256:09f7da3bc104798d0afb40bc08d23ab2da20a76130cec1f2ef170848f5d85217
WORKDIR /app
COPY app.py /app/app.py
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,os;urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz',timeout=3)" || exit 1
CMD ["python", "app.py"]
