from dateutil.parser.isoparser import isoparser

_date_time_parser = isoparser(sep=',')

msg3_valid = {
    'transmission_type': 3,
    'hexident': 'hex_msg3_valid',
    'gen_date_time': _date_time_parser.isoparse('2019/10/20,11:33:40.311'.replace('/', '-')),
    'log_date_time': _date_time_parser.isoparse('2019/10/20,11:33:40.311'.replace('/', '-')),
    'callsign': None,
    'altitude': 3000,
    'speed': 300,
    'track': 0,
    'latitude': 46.65470,
    'longitude': -2.77776,
    'onground': False
    }

# Landing R21
#identify_onground_change for : Position 389063 of flight 713 at 2020-02-24 19:34:58.774000+00:00: [(-1.23695,
# 47.13684, 2103.12)] (onground=False)
#identify_onground_change for : Position 389064 of flight 713 at 2020-02-24 19:34:59.181000+00:00: [(-1.23723,
# 47.13731, 2095.5)] (onground=False)
#identify_onground_change for : Position 389065 of flight 712 at 2020-02-24 19:34:59.594000+00:00: [(-1.61046, 47.15356, 0.0)] (onground=True)

# Landing on R03
#identify_onground_change for : Position 390672 of flight 733 at 2020-02-24 22:07:53.456000+00:00: [(-1.61238,
# 47.15095, 0.0)] (onground=False)
#identify_onground_change for : Position 390673 of flight 733 at 2020-02-24 22:07:55.490000+00:00: [(-1.61177,
# 47.15177, 0.0)] (onground=True)