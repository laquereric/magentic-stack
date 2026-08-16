# The mandatory, distinct CPCP FRONT pod. No Rails: a thin JSON-RPC-LD client
# that talks to the Rails BACK over the wire.
FROM python:3.12-slim
WORKDIR /app
COPY app.py /app/app.py
ENV PORT=8080
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s CMD python -c "import urllib.request,os;urllib.request.urlopen('http://127.0.0.1:'+os.environ.get('PORT','8080')+'/healthz',timeout=3)" || exit 1
CMD ["python", "app.py"]
