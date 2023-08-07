import json

class MobilityModel():
    def __init__(self, city_folder, seed = 0):
        self.seed = seed
        self.city_folder = city_folder
        trip_attrs_path = './cities/'+city_folder+'/clean/trip_attributes.json'
        self.trip_attrs = json.load(open(trip_attrs_path))
        self.ALL_ZONES_PATH = './cities/'+city_folder+'/clean/model_area.geojson'
        self.SIM_ZONES_PATH = './cities/'+city_folder+'/clean/sim_zones.json'
        self.GEOGRID_PATH = './cities/'+city_folder+'/clean/geogrid.geojson'

        self.build_model()

    def build_model(self):
        self.build_transport_networks()
        self.build_geography()
        self.build_synth_pop()

    def build_transport_networks(self):
        print('Building transport network')
        self.tn = Transport_Network('westminster', 'London')