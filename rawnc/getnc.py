import sys
import json

var = sys.argv[1]
experiment = sys.argv[2]
source = sys.argv[3]


dict = {
	"search_api": "https://esgf-node.llnl.gov/esg-search/search/",
	"data_node_priority": ["aims3.llnl.gov", "esgf-data1.llnl.gov"],
	"fields": {
		"variable_id": var,
		"experiment_id": experiment,
		"source_id": source,
		"table_id": "day",
        "variant_label": "r1i1p1f1",
        "project": "CMIP6"
	}
}

with open('params.json', 'w') as outfile:
    json.dump(dict, outfile)