import os
import json
import sys

if __name__ == "__main__":

	process_count = int(sys.argv[1])

	mode = int(sys.argv[2])

	if(mode == 1):
		for i in range(1, process_count+1):
			os.system("python3 generate_requests.py 100000 1 requests" + str(i) + ".txt &")
	elif(mode == 2):
		for i in range(1, process_count+1):
			os.system("python bulk_script.py requests" + str(i) + ".txt output3.json 2 &")
	exit(1)