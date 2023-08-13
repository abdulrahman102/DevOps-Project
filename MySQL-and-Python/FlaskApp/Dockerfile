FROM python:2.7.18-slim-stretch
WORKDIR /python-docker
COPY requirements.txt requirements.txt
RUN pip install -r requirements.txt
COPY . .
CMD [ "python", "app.py" ]
EXPOSE  5002