from jinja2 import Template
import json
import os, sys, time
import argparse


def used_opts(jsonoutFile, parmsFile, tplateFile):
    print("Command line options specified:")
    print("\tJSON output file: %s \n"
          "\tParms file: %s \n"
          "\tTemplate file: %s \n"
          % (jsonoutFile, parmsFile, tplateFile))


def main(argv):
    jsonoutFile = ''
    parmsFile = ''
    tplateFile = ''

    # Parse Command Line Arguments:
    #   o/outfile           Output file
    #   p|parms				JSON parameters
    #   t|template          Control-M JSON template
    #

    parser = argparse.ArgumentParser(description='Render Control-M JSON from Jinja2 Template')
    parser.add_argument("-o", "--outfile", dest='jsonoutFile', type=str, required=False,
                        help='Output JSON file')
    parser.add_argument("-p", "--parms", dest='parmsFile', type=str, required=True,
                        help='jinja2 parameters in JSON file')
    parser.add_argument('-t', '--template', dest='tplateFile', type=str, required=True,
                        help='Control-M JSON as Jinja template file')
    args = parser.parse_args()

    used_opts(args.jsonoutFile, args.parmsFile, args.tplateFile)

    # Get Template and Parms
    jinja2_template_string = open(args.tplateFile, 'r').read()
    with open(args.parmsFile) as f:
        tvars = json.load(f)

    # Create Template Object
    template = Template(jinja2_template_string)

    # Render JSON Template String
    json_template_string = template.render(tvars)

    if args.jsonoutFile:
        of = open(args.jsonoutFile, "w")
        of.write(json_template_string)
        of.close()
    else:
        print(json_template_string)

    sys.exit(0)

if __name__ == '__main__':
    main(sys.argv[1:])
