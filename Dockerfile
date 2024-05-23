# 
FROM python:3.9

# 
WORKDIR /code

# 
COPY ./requirement/requirements.txt /code/requirements.txt

# 
RUN pip install --no-cache-dir --upgrade -r /code/requirements.txt

# 
COPY ./hello_world /code/hello_world
COPY ./app.py /code/app.py

# 
CMD ["fastapi", "run", "app.py", "--port", "8081"]