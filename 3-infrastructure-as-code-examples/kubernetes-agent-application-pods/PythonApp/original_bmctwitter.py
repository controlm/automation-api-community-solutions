from tweepy import Stream
from tweepy import OAuthHandler
from tweepy.streaming import StreamListener
import simplejson as json
import yaml
import sys
import logging
from kafka import KafkaProducer
from datetime import date

def today():
    return " " + date.today().strftime('%Y-%m-%d %H:%M:%S')

def parseTweet(j):

    try:
        tt = {}
        tt['geo'] = j['geo'] 
        tt['entities'] = j['entities']
        tt['tweet'] = j['text']
        tt['screenName'] = j['user']['screen_name']
        return json.dumps(tt)
    except KeyError:
        logging.info("key error" + sys.exc_info()[1] + today().strftime('%Y-%m-%d %H:%M:%S'))
        return json.dumps(j)

class Listener(StreamListener):

      1 == 1;


class ListenerChild(Listener):

      def __init__(self,api,producer):
          self.producer=producer
          super().__init__(api)

      def on_data(self, data):
        j = json.loads(data)
        try:
            if j['geo'] is not None:
                tt = parseTweet(j)
                logging.info(tt)
                logging.info (tt)
                self.producer.send('tweets', bytearray(tt,'utf-8'))
        except KeyError:
            logging.info ("rate limited" + date.today().strftime('%Y-%m-%d %H:%M:%S'))

def readTweets(producer,region, consumer_key, consumer_secret, access_token, access_token_secret,languages,track):

    auth = OAuthHandler(consumer_key, consumer_secret)
    auth.set_access_token(access_token, access_token_secret)

    # stream = Stream(auth=auth, listener=Listener(),wait_on_rate_limit=True,wait_on_rate_limit_notify=True)
    stream = Stream(auth=auth, listener=ListenerChild(api=None,producer=producer),wait_on_rate_limit=True,wait_on_rate_limit_notify=True)

    logging.info("tracking languages {0} location {1} track {2}".format(languages, region, track)) 

    stream.filter(locations=region,languages=languages,track=track)

def main():

    logging.basicConfig(level=logging.INFO)
    logging.basicConfig(filename='twitterKafka.log', filemode='w', format='%(name)s - %(levelname)s - %(message)s')

    try:
        configFile = sys.argv[1]
    except IndexError:
        print ("usage: yaml config file") + today()
        logging.info("usage: yaml config file") + today()
        sys.exit(2) 
 
    try:
        config = yaml.load(open(configFile)) 
    except FileNotFoundError:
        logging.info("cannot find YAML file " + configFile) + today()
        sys.exit(2)

    try:
        consumer_key = config['consumer_key']
        consumer_secret = config['consumer_secret']    
        access_token = config['access_token']
        access_token_secret = config['access_token_secret']
        region = [ config['bottomLongitude'], config['bottomLatitude'], config['topLongitude'], config['topLatitude'] ]
        track = config['track']
        languages = config['languages']
    except KeyError:
        print ("YAML file not complete") + today()
        logging.info("YAML file not complete") + today()
        sys.exit(2)

    producer = KafkaProducer(bootstrap_servers='localhost:9092')

    readTweets(producer,region, consumer_key, consumer_secret, access_token, access_token_secret,languages, track)

if __name__ == "__main__":
    main()
