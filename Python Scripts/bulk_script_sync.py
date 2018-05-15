import json
import requests
import time
import sys

REQ_URL 				= "http://35.231.247.20:8000/api/tx.yaws"
REQ_HEADER 				= {'content-type': 'application/json'}
PARAM_FILE_NAME 		= "requests.txt"
TIMESTAMP_MS_MULTIPLY	= 1000000
NS_TO_MS 				= 1000 * 1.0

def singleRequest(paramValue):
	# print(paramValue);
	totalTime = 0
	networkTime = 0
	paxosTime = 0

	requestTimestamp = int(time.time() * TIMESTAMP_MS_MULTIPLY)
	payload = { 
		"jsonrpc" : "2.0", 
		"method" : "req_list", 
		"params" : paramValue, 
		"id" : 0 
	};
	[ [ { "write" : { "R" : {"type" : "as_is", "value" : "23"} } }, { "commit" : "" } ] ]
	# [ [ { "write" : { "keyA" : {"type" : "as_is", "value" : "valueA"} } }, { "write" : { "keyB" : {"type" : "as_is", "value" : "valueB"} } }, { "commit" : "" } ] ], 
	try:
		r = requests.post(REQ_URL, data = json.dumps(payload), headers=REQ_HEADER)
		responseTimestamp = int(time.time() * TIMESTAMP_MS_MULTIPLY)
		# print(r.text)
		r_response = json.loads(r.text)
		if "result" in r_response and "results" in r_response["result"]:
			# print(r_response["result"]["results"])
			resultsArr = r_response["result"]["results"]
			for item in resultsArr:
				if "timestamp" in item:
					# print(requestTimestamp, responseTimestamp, item["timestamp"], time.time())
					totalTime = (responseTimestamp - requestTimestamp)/NS_TO_MS
					networkTime = (responseTimestamp - item["timestamp"])/NS_TO_MS
					paxosTime = ((item["timestamp"] - requestTimestamp)/NS_TO_MS)
					paxosTime -= networkTime

					totalTime = round(totalTime, 2)
					networkTime = round(networkTime, 2)
					paxosTime = round(paxosTime, 2)

					return (totalTime, paxosTime, networkTime)
	except ValueError:
		print("Failed to update scalaris")


def init():
	# if(len(sys.argv) != 3):
	# 	print("Sample Request: python bulk_script.py input_file_name.txt output_file_name.json")
 #        exit(1)

	input_file_name = sys.argv[1]
	output_file_name = sys.argv[2]

	print_logs_flag = int(sys.argv[3])

	print(input_file_name)
	print(output_file_name)

	scalarisResponse = []
	with open("./" + input_file_name) as f:
		wf = open(output_file_name, "a", 0)
		wf.write("[");
		
		for paramValue in f:
			try:
				(totalTime, paxosTime, networkTime) = singleRequest(json.loads(paramValue.strip()))
				if print_logs_flag is 1 :
					print("Total Time: ", totalTime)
					print("Paxos Time: ", paxosTime)
					print("Network Time: ", networkTime)
				# scalarisResponse.append([totalTime, paxosTime, networkTime])

				wf.write(json.dumps([totalTime, paxosTime, networkTime]))
				wf.write(", ");
			except:
				print("Failed to make request to singleRequest")
		
		wf.write("]");
		wf.close()

			# paramValue = paramValue.strip()
			# requestTimestamp = time.time()
	  #   	payload = { 
	  #   		"jsonrpc" : "2.0", 
	  #   		"method" : "req_list", 
	  #   		"params" : json.loads(paramValue), 
	  #   		"id" : 0 
	  #   	};
	  #   	r = requests.post(REQ_URL, data = json.dumps(payload), headers=REQ_HEADER)
	  #   	responseTimestamp = time.time()
	  #   	print(r.text)
	   #  	r_response = json.loads(r.text)
	   #  	if "result" in r_response and "results" in r_response["result"]:
				# print(r_response["result"]["results"])
				# resultsArr = r_response["result"]["results"]
				# for item in resultsArr:
				# 	if "timestamp" in item:
				# 		print(requestTimestamp, responseTimestamp, item["timestamp"])
				# 		print("Total Time: ", responseTimestamp - requestTimestamp)
				# 		print("Paxos Time: ", item["timestamp"] - requestTimestamp)
				# 		print("Network Time: ", responseTimestamp - item["timestamp"])

if __name__ == "__main__":
	
	init()
	# singleRequest()
