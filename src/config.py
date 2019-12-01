import os


def get_env_variable(name):
    try:
        return os.environ[name]
    except KeyError:
        message = "Expected environment variable '{}' not set.".format(name)
        raise Exception(message)


DUMP1090_HOST = get_env_variable("DUMP1090_HOST")
DUMP1090_PORT = get_env_variable("DUMP1090_PORT")
POSTGRES_HOST = get_env_variable("POSTGRES_HOST")
POSTGRES_PORT = get_env_variable("POSTGRES_PORT")
POSTGRES_USER = get_env_variable("POSTGRES_USER")
POSTGRES_PW = get_env_variable("POSTGRES_PW")
POSTGRES_DB = get_env_variable("POSTGRES_DB")
DB_URL = 'postgresql+psycopg2://{user}:{pw}@{host}:{port}/{db}'.format(user=POSTGRES_USER, pw=POSTGRES_PW,
                                                                       host=POSTGRES_HOST, port=POSTGRES_PORT,
                                                                       db=POSTGRES_DB)
