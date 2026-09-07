FROM python:3.10-alpine

WORKDIR /code

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    FLASK_APP=hello.py \
    FLASK_RUN_PORT=8000 \
    FLASK_RUN_HOST=0.0.0.0

RUN addgroup -S app && adduser -S app -G app

COPY requirements.txt /code
RUN pip3 install --no-cache-dir -r requirements.txt

COPY hello.py /code
RUN chown -R app:app /code

USER app
EXPOSE 8000

HEALTHCHECK --interval=10s --timeout=3s --retries=5 \
  CMD python -c "import urllib.request; urllib.request.urlopen('http://127.0.0.1:8000/')"

CMD ["flask", "run"]
