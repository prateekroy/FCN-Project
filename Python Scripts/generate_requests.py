#!/usr/bin/python3

import sys
import string
import random

def random_read_request():
    req_str = ""
    req_str += '[ [ { "read" :' + '"' + str(random.choice(string.ascii_letters))  + '"} ] ]'
    return req_str


def random_write_request():
    req_str = ""
    req_str += '[ [ { "write" : { ' + '"' + str(random.randint(1, 99999999))  + '" : {"type" : "as_is", "value" : "' \
            + str(random.randint(1,10001)) + '"} } }, { "commit" : "" } ] ]'
    return req_str

if(__name__ == "__main__"):
    if len(sys.argv) != 4:
        print ("Exiting. Send size and type of request to be created !!! \n")
        print ("1 - write request, 2 - read request and 3 - mixed request")
        exit(1)

    print("Request file created is : requests.txt \n") 
    output_file_name = sys.argv[3]
    request_file = open(output_file_name,'w')
    if (int(sys.argv[2]) == 1):
        for num in range(int(sys.argv[1])):
            request_file.write( random_write_request() + "\n")
    elif (int(sys.argv[2]) == 2):
        for num in range(int(sys.argv[1])):
            request_file.write( random_read_request() + "\n")
    else:
        for num in range(int(sys.argv[1])):
            if (random.randint(1,2) == 1):
                request_file.write( random_write_request() + "\n")
            else:
                request_file.write(random_read_request() + "\n")
    request_file.close()
    print("you passed")
