from sqlalchemy import create_engine, desc, exc, event, select
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.dialects import postgresql
from sqlalchemy.orm import sessionmaker
from sqlalchemy import Column, Integer, String, Text, text, Boolean
from sqlalchemy.sql.sqltypes import TIMESTAMP
from sqlalchemy.sql.functions import current_timestamp

from datetime import datetime, timedelta

class database(object):
  def __init__(self, url, __logger):
    db_engine = create_engine(url)
    Base.metadata.create_all(db_engine)
    self.Session = sessionmaker(bind=db_engine)
    self.__logger = __logger

  def get_latest_posts(self, days):
    # SELECT * FROM posts WHERE datestamp > (current_timestamp - INTERVAL '$days days') ORDER BY DATESTAMP DESC
    X_days_ago = datetime.now() - timedelta(days=days)
    return self.Session().query(Post).filter(Post.datestamp >= X_days_ago).order_by(desc(Post.datestamp))

Base = declarative_base()

class Post(Base):
  __tablename__ = 'posts'

  id = Column(Integer, autoincrement=True, primary_key=True)
  datestamp = Column(TIMESTAMP, nullable=False, server_default=text("NOW()"), index=True)
  url = Column(String)
  urltext = Column(String)
  threadurl = Column(String)
  threadtitle = Column(Text)
  # threadtitle_ts_indexed tsvector
  forum = Column(String)
  whoid = Column(Integer)
  who = Column(String)
  whourl = Column(String)
  precis = Column(Text)
  # precis_ts_indexed tsvector
  guid_url = Column(String)
  fulltext = Column(Text)
  # fulltext_ts_indexed tsvector
  fulltext_stripped = Column(Text)
  fulltext_noquotes = Column(Text)
  # fulltext_noquotes_ts_indexed tsvector
  fulltext_noquotes_stripped = Column(Text)
  available = Column(Boolean)
