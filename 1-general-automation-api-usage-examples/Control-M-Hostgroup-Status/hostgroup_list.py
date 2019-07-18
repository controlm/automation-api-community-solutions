#!/usr/bin/env python3

import argparse
import sys
import json
from pathlib import Path
from Crypto.Cipher import AES
import base64
from Crypto import Random
import os
import requests
import urllib3
import queue
import threading
from tabulate import tabulate

urllib3.disable_warnings(urllib3.exceptions.InsecureRequestWarning)


BS = 16
pad = lambda s: s + (BS - len(s) % BS) * chr(BS - len(s) % BS)
unpad = lambda s: s[0:-s[-1]]


default_env = {
    "environments": {},
    "currentEnv": ""
}

# load config
aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
if not os.path.isdir(Path.home() / ".ctm_hostgroup_list"):
    os.mkdir(str(aapifolderpath), 0o700)
configfile = aapifolderpath / 'config.json'
if not os.path.exists(configfile):
    default_cfg = {"threads": 3, "tls_verify": False}
    cfgfile = open(str(configfile), "w")
    json.dump(default_cfg, cfgfile, sort_keys=True, indent=4, separators=(',', ': '))
    cfgfile.close()

cfgfile = open(str(configfile), "r")
cfg = json.load(cfgfile)
cfgfile.close()



class AESCipher:

    def __init__(self, key):
        self.key = key

    def encrypt(self, raw):
        raw = pad(raw)
        iv = Random.new().read(AES.block_size)
        cipher = AES.new(self.key, AES.MODE_CBC, iv)
        return base64.b64encode(iv + cipher.encrypt(raw.encode('utf-8'))).decode('utf-8')

    def decrypt(self, enc):
        enc = base64.b64decode(enc)
        iv = enc[:16]
        cipher = AES.new(self.key, AES.MODE_CBC, iv)
        return unpad(cipher.decrypt(enc[16:])).decode('utf-8')


class env(object):
    def __init__(self):
        parser = argparse.ArgumentParser(
            description='Configure the Test Runner''s \
        connection information to the AAPI endpoint',
            usage='''test_jobs.py conf <subcommand> [<args>]
            subcommands:
                add  - add an environment
                rm   - delete an environment
                show - list the defined environments
                set  - set the default environment'''
        )
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[2:3])
        if not hasattr(self, args.command):
            print('Unrecognized command')
            parser.print_help()
            exit(1)
        # use dispatch pattern to invoke method with same name
        getattr(self, args.command)()

    def add(self):
        parser = argparse.ArgumentParser(description='Configure the Test Runner''s \
                connection information to the AAPI endpoint')
        parser.add_argument('Name', help='Name of the environment to add')
        parser.add_argument('EndPoint', help='AAPI Endpoint, ex: https://emhost:8443/automation-api')
        parser.add_argument('User', help='AAPI Username')
        parser.add_argument('Password', help='AAPI Password')
        args = parser.parse_args(sys.argv[3:])
        aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
        envkeypath = aapifolderpath / "env.key"
        envjsonpath = aapifolderpath / "env.json"
        if not os.path.isdir(Path.home() / ".ctm_hostgroup_list"):
            os.mkdir(str(aapifolderpath), 0o700)
        if not os.path.exists(Path.home() / ".ctm_hostgroup_list/env.key"):
            key = os.urandom(BS)
            with open(str(envkeypath), "wb") as keyfile:
                keyfile.write(key)
        else:
            with open(str(envkeypath), "rb") as keyfile:
                key = keyfile.read()

        args.Password = AESCipher(key).encrypt(args.Password)

        if not os.path.exists(Path.home() / ".ctm_hostgroup_list/env.json"):
            envfile=open(str(envjsonpath), "w")
            env = default_env
        else:
            envfile = open(str(envjsonpath), "r")
            env = json.load(envfile)
            envfile.close()
            envfile = open(str(envjsonpath), "w")
        newenv = {"endPoint": args.EndPoint, "user": args.User, "password": args.Password}
        env['environments'][args.Name] = newenv
        json.dump(env, envfile)
        envfile.close()

    def rm(self):
        parser = argparse.ArgumentParser(description='remove an environment from the Test Runner''s \
                        configuration')
        parser.add_argument('Name', help='Name of the environment to add')
        args = parser.parse_args(sys.argv[3:])
        aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
        envjsonpath = aapifolderpath / "env.json"
        if not os.path.exists(Path.home() / ".ctm_hostgroup_list/env.json"):
            print("Environtment file not found!")
            exit(1)
        else:
            envfile = open(str(envjsonpath), "r")
            env = json.load(envfile)
            envfile.close()
            if args.Name in env['environments']:
                env['environments'].pop(args.Name)
                envfile = open(str(envjsonpath), "w")
                json.dump(env, envfile)
                envfile.close()
            else:
                print("No such environment, %s, in environments file!" % args.Name)
                exit(1)

    def show(self):
        aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
        envjsonpath = aapifolderpath / "env.json"
        if not os.path.exists(Path.home() / ".ctm_hostgroup_list/env.json"):
            print("Environtment file not found!")
            exit(1)
        else:
            envfile = open(str(envjsonpath), "r")
            env = json.load(envfile)
            envfile.close()
            tmpe = {}
            for e in list(env['environments']):
                tmpe[e] = { "endPoint": env['environments'][e]['endPoint'], "user": env['environments'][e]['user']}
            currenv = env['currentEnv']
            print("Current Environment: " + currenv)
            print("Environments: ")
            print(json.dumps(tmpe, indent=4, separators=(',', ': ')))

    def set(self):
        parser = argparse.ArgumentParser(description='Set the default environment')
        parser.add_argument('Name', help='Name of the environment to add')
        args = parser.parse_args(sys.argv[3:])
        aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
        envjsonpath = aapifolderpath / "env.json"
        if not os.path.exists(Path.home() / ".ctm_hostgroup_list/env.json"):
            print("Environtment file not found!")
            exit(1)
        else:
            envfile = open(str(envjsonpath), "r")
            env = json.load(envfile)
            envfile.close()
            if args.Name not in env['environments']:
                print("Not such environment defined!")
                exit(1)
            else:
                env['currentEnv'] = args.Name
                with open(str(envjsonpath), "w") as f:
                    json.dump(env, f)


class lst(object):
    def __init__(self):

        parser = argparse.ArgumentParser(
            description='Check and Run tests',
        )
        parser.add_argument('CtmServer', metavar='CtmServer', help='The Control-M/Server under which to list the hostgroups')
        parser.add_argument('-t', metavar='timeout', help='Control-M/Agent connection check timeout')
        self.args = parser.parse_args(sys.argv[2:])
        self.env = self.load_env()
        self.aglist = []
        workqueue = queue.Queue()

        reauth = threading.Event()
        reauth.set()
        cache = {}
        res = {}
        #resmap = [hostgroup1: [agent1: A, agent2: U], hostgroup2: [agentb: A, agent2: U, ...], ...]
        self.resmap = {'hostgroups': {}}

        cache['token'] = self.update_token()
        # thread endpoint = self.env['environments'][currentEnv]['endPoint'] + '/config/server/' + self.args.CtmServer

        hg_lst = self.gethostgroups(self.args.CtmServer, cache)
        self.getagents(self.args.CtmServer, hg_lst, workqueue, cache)
        threads_lst = list()
        for i in range(cfg['threads']):
            x = threading.Thread(target=self.worker_thread,
                                 args=(workqueue, reauth, cache,
                                       self.env['environments'][self.env['currentEnv']]['endPoint'] +
                                       '/config/server/' + self.args.CtmServer, self.update_token, res), daemon=False)
            threads_lst.append(x)
            x.start()

        workqueue.join()

        for ag in res:
            for hg in self.resmap['hostgroups']:
                if ag in self.resmap['hostgroups'][hg]:
                    self.resmap['hostgroups'][hg][ag] = res[ag]

        self.print_res()

    def print_res(self):
        print("")
        for h in self.resmap['hostgroups']:
            tmp = []
            for a in self.resmap['hostgroups'][h]:
                tmp.append([a, self.resmap['hostgroups'][h][a]])
            print("Hostgroup: %s" % h)
            print(tabulate(tmp, tablefmt="grid", headers={'host', 'status'}))


    def getagents(self, ctm, hglst, q, t_cache):
        for i in hglst:
            try:
                r = requests.get(self.env['environments'][self.env['currentEnv']]['endPoint'] + '/config/server/' + ctm +
                                 '/hostgroup/' + i + '/agents', headers={"Authorization": "Bearer " + t_cache['token']},
                                 verify=cfg['tls_verify'])
                if 'errors' in json.loads(r.text):
                    print("Unable to list agents in hostgroup %s!", i)
                    print(json.dumps(json.loads(r.text)['errors'][0]['message']))
                    quit(1)
                else:
                    aglst = json.loads(r.text)
                    for x in aglst:
                        # self.resmap['hostgroups'][self.resmap['hostgroups'].index(i)].append({x['nodeid']: '.'})
                        self.resmap['hostgroups'][i][x['host']] = '.'
                        if x['host'] not in self.aglist:
                            self.aglist.append(x['host'])
                            q.put(x['host'])

            except requests.exceptions.ConnectTimeout as err:
                print("Connecting to Automation API REST Server failed with error: " + str(err))
                exit(1)
            except requests.exceptions.ConnectionError as err:
                print("Connecting to Automation API REST Server failed with error: " + str(err))
                if 'CERTIFICATE_VERIFY_FAILED' in str(err):
                    print(
                        'INFO: If using a Self Signed Certificate use the -i flag to disable cert verification or \
                        add the certificate to this systems trusted CA store')
                exit(1)
            except requests.exceptions.HTTPError as err:
                print("Connecting to Automation API REST Server failed with error: " + str(err))
                exit(1)
            # except:
            #     print("Connecting to Automation API REST Server failed with error unknown error")
            #     exit(1)


    def gethostgroups(self, ctm, t_cache):
        try:
            r = requests.get(self.env['environments'][self.env['currentEnv']]['endPoint'] + '/config/server/' + ctm +
                             '/hostgroups', headers={"Authorization": "Bearer " + t_cache['token']},
                             verify=cfg['tls_verify'])
            if 'errors' in json.loads(r.text):
                print("Unable to get hostgroups!")
                print(json.dumps(json.loads(r.text)['errors'][0]['message']))
                quit(1)
            else:
                for i in json.loads(r.text):
                    # self.resmap['hostgroups'].append({i: []})
                    self.resmap['hostgroups'][i] = {}
                return json.loads(r.text)
        except requests.exceptions.ConnectTimeout as err:
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            exit(1)
        except requests.exceptions.ConnectionError as err:
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            if 'CERTIFICATE_VERIFY_FAILED' in str(err):
                print(
                    'INFO: If using a Self Signed Certificate use the -i flag to disable cert verification or \
                    add the certificate to this systems trusted CA store')
            exit(1)
        except requests.exceptions.HTTPError as err:
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            exit(1)
        # except:
        #     print("Connecting to Automation API REST Server failed with error unknown error")
        #     exit(1)

    @staticmethod
    def worker_thread(q, ReAuthEvnt, t_cache, endPoint, t_update_func, res):
        # while not q.empty():
        while True:
            if q.empty():
                break
            else:
                if ReAuthEvnt:
                    ReAuthEvnt.wait()
                ag = q.get()
                try:
                    r = requests.post(endPoint + '/agent/' + ag + '/ping',
                                      headers={"Authorization": "Bearer " + t_cache['token']}, json={"discover": False,
                                                                                                     "timeout": 30},
                                      verify=cfg['tls_verify'])

                    if 'errors' in json.loads(r.text):
                        if 'Session token is invalid or expired' in json.loads(r.text)['errors'][0]['message']:
                            if not ReAuthEvnt.is_set():
                                ReAuthEvnt.clear()  # Appears counter intuitive to "clear" the event but the clear function \
                                # causes all other threads waiting on the event to block until the event is set back to \
                                # true via the set() function
                                t_cache['token'] = t_update_func()
                                q.put(ag)
                                ReAuthEvnt.set()
                            else:
                                q.put(ag)
                                ReAuthEvnt.wait()
                    else:
                        if 'is unavailable' in json.loads(r.text)['message']:
                            res[ag] = 'Offline'
                        elif 'is available' in json.loads(r.text)['message']:
                            res[ag] = 'Online'
                        else:
                            print('Failed to parse Control-M/Agent Status message for %s', ag)
                            quit(1)
                        q.task_done()
                except requests.exceptions.ConnectTimeout as err:
                    print("Connecting to Automation API REST Server failed with error: " + str(err))
                    exit(1)
                except requests.exceptions.ConnectionError as err:
                    print("Connecting to Automation API REST Server failed with error: " + str(err))
                    if 'CERTIFICATE_VERIFY_FAILED' in str(err):
                        print(
                            'INFO: If using a Self Signed Certificate use the -i flag to disable cert verification or add the certificate to this systems trusted CA store')
                    exit(1)
                except requests.exceptions.HTTPError as err:
                    print("Connecting to Automation API REST Server failed with error: " + str(err))
                    exit(1)
                # except:
                #     print("Connecting to Automation API REST Server failed with error unknown error")
                #     exit(1)

    @staticmethod
    def load_env():
        aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
        envjsonpath = aapifolderpath / "env.json"
        if not os.path.isdir(str(aapifolderpath)):
            print("Can't find .ctm_hostgroup_list directory!")
            exit(1)
        if not os.path.exists(str(envjsonpath)):
            print("Can't find env.json file!")
            exit(1)
        with open(envjsonpath, "r") as f:
            return json.load(f)

    def update_token(self):
        aapifolderpath = Path(Path.home() / ".ctm_hostgroup_list")
        envkeypath = aapifolderpath / "env.key"
        if not os.path.isdir(str(aapifolderpath)):
            print("Can't find .ctm_hostgroup_list directory!")
            exit(1)
        if not os.path.exists(str(envkeypath)):
            print("Can't find env.key file!")
            exit(1)
        with open(envkeypath, "rb") as f:
            key = f.read()

        currentEnv = self.env['currentEnv']
        user = self.env['environments'][currentEnv]['user']
        password = self.env['environments'][currentEnv]['password']
        endPoint = self.env['environments'][currentEnv]['endPoint']

        try:
            r = requests.post(endPoint + '/session/login',
                              json={"password": AESCipher(key).decrypt(password), "username": user},
                              verify=cfg['tls_verify'])

            # print(r.text)
            loginresponce = json.loads(r.text)
            if 'errors' in loginresponce:
                print(json.dumps(loginresponce['errors'][0]['message']))
                quit(1)
            elif 'token' in loginresponce:  # If token exists in the json response set the value to the variable token
                return json.loads(r.text)['token']
        except requests.exceptions.ConnectTimeout as err:
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            exit(1)
        except requests.exceptions.ConnectionError as err:
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            if 'CERTIFICATE_VERIFY_FAILED' in str(err):
                print(
                    'INFO: If using a Self Signed Certificate use the -i flag to disable cert verification or add the certificate to this systems trusted CA store')
            exit(1)
        except requests.exceptions.HTTPError as err:
            print("Connecting to Automation API REST Server failed with error: " + str(err))
            exit(1)
        # except:
        #     print("Connecting to Automation API REST Server failed with error unknown error")
        #     exit(1)




class ListHostGroups(object):

    def __init__(self):
        parser = argparse.ArgumentParser(
            description='List Control-M Hostgroups via Automation API',
            usage='''hostgroup_list.py <command> [<args>]
            commands:
                list - run test
                env - configure environment'''
        )
        parser.add_argument('command', help='Subcommand to run')
        args = parser.parse_args(sys.argv[1:2])
        if not hasattr(self, args.command):
            print('Unrecognized command')
            parser.print_help()
            exit(1)
        # use dispatch pattern to invoke method with same name
        getattr(self, args.command)()

    def env(self):
        env()

    def list(self):
        lst()


if __name__ == '__main__':
    ListHostGroups()
