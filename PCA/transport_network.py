import numpy as np
import json
from shapely.geometry import Point, shape
import pandas as pd
import networkx as nx
from scipy import spatial

class Mode():
    def __init__(self, mode_descrip, mode_id):
        self.speed_met_s = mode_descrip['speed_m_s']
        self.name = mode_descrip['name']
        self.activity = mode_descrip['activity']
        self.internal_net = mode_descrip['internal_net']
        self.co2_emissions_kg_met = mode_descrip['co2_emissions_kg_met']
        self.fixed_costs = mode_descrip['fixed_costs']
        self.id = mode_id

def approx_shape_centroid(geometry):
    if geometry['type'] == 'Polygon':
        centroid = list(np.mean(geometry['coordinates'][0], axis=0))
        return centroid
    elif geometry['type'] == 'MultiPolygon':
        centroid = list(np.mean(geometry['coordinates'][0][0], axis=0))
        return centroid
    else:
        print('Unknown geometry type')


class Polygon_Location():
    def __init__(self, geometry, area_type, in_sim_area, geoid=None):
        self.area_type = area_type
        self.geometry = geometry
        self.centroid = approx_shape_centroid(geometry)
        self.in_sim_area = in_sim_area
        self.geoid = geoid

class Route():
    def __init__(self, internal_route, costs, pre_time=0, post_time=0):
        self.internal_route = internal_route
        self.pre_time = pre_time
        self.post_time = post_time
        self.costs = costs

class Transport_Network():
    def __init__(self, city_folder):
        mode_description = json.load(open('./cities/'+city_folder+'/clean/mode_descriptions.json'))
        self.city_folder = city_folder
        self.ROUTE_COSTS_PATH = './cities/'+city_folder+'/clean/route_costs.json'
        self.INT_NET_PATH = './cities/'+city_folder+'/clean/'
        self.SIM_AREA_PATH = './cities/'+city_folder+'/clean/table_area.geojson'
        self.PORTALS_PATH = './cities/'+city_folder+'/clean/portals.geojson'
        self.base_modes = [Mode(d, mode_id) for mode_id, d in enumerate(mode_description)]
        # route costs
        try:
            self.external_cost = json.load(open(self.ROUTE_COSTS_PATH))
        except:
            print('External routes not yet prepared. Preparing now')
            self.prepare_external_routes()
            self.external_costs = json.load(open(self.ROUTE_COSTS_PATH))

    def rename_nodes(nodes_df, edges_df, node_id_name, to_name, from_name):
        nodes_df['old_node_id'] = nodes_df[node_id_name].copy()
        nodes_df['node_id'] = range(len(nodes_df))
        node_name_map = {nodes_df.iloc[i]['old_node_id']:i for i in range(len(nodes_df))}
        rev_node_name_map = {v: str(k) for k,v in node_name_map.items()}
        edges_df['from_node_id'] = edges_df.apply(lambda row: node_name_map[row[from_name]], axis = 1)
        edges_df['to_node_id'] = edges_df.apply(lambda row: node_name_map[row[to_name]], axis = 1)
        return nodes_df, edges_df, rev_node_name_map

    def find_route_multi(start_nodes, end_nodes, graph, weight):
        for sn in start_nodes:
            for en in end_nodes:
                try:
                    node_path = nx.dijkstra_path(graph, sn, en, weight = weight)
                    return node_path
                except:
                    pass
        return None

    def prepare_external_routes(self):
        import osmnet
        ALL_ZONES_PATH = './cities/'+self.city_folder+'/clean/model_area.geojson'
        # public transit & pedestrian(need to find this network map)
        PT_NODES_PATH = './cities/'+self.city_folder+'/clean/comb_networks_nodes.csv'
        PT_EDGES_PATH = './cities/'+self.city_folder+'/clean/comb_networks_edges.csv'
        PED_NODES_PATH = './cities/'+self.city_folder+'/clean/osm_ped_network_nodes.csv'
        PED_EDGES_PATH = './cities/'+self.city_folder+'/clean/osm_ped_network_edges.csv'

        SPEEDS_MET_S = {
            'driving':30/3.6,
            'cycling':15/3.6,
            'walking':4.8/3.6,
            'pt':4.8/3.6
        }

        pandana_link_types={'osm to transit': 'waiting',
                            'transit to osm': 'waiting',
                            'walk': 'walking',
                            'transit': 'pt'
                            }
        #Load network data
        all_zones_shp = json.load(open(ALL_ZONES_PATH))
        all_zones_geoid_order = [f['properties']['GEO_ID'].split('US')[1] for f in all_zones_shp['features']]

        portals = json.load(open(self.PORTALS_PATH))

        largeArea = [shape(f['geometry']) for f in all_zones_shp['features']]
        bounds = [shp.bounds for shp in largeArea]
        boundsAll = [
            min([b[0] for b in bounds]), #w
            min([b[1] for b in bounds]), #s
            max([b[2] for b in bounds]), #e
            max([b[3] for b in bounds]) #n
        ]

        drive_nodes, drive_edges = osmnet.load.network_from_bbox(
            lat_max = boundsAll[3],
            lat_min = boundsAll[1],
            lng_max = boundsAll[2],
            lng_min = boundsAll[0],
            bbox = None, network_type = 'drive',
            two_way = True, timeout = 180,
            custom_osm_filter = None
            )

        cycle_nodes, cycle_edges = drive_nodes.copy(), drive_edges.copy()

        #pt
        pt_edges = pd.read_csv(PT_EDGES_PATH)
        pt_nodes = pd.read_csv(PT_NODES_PATH)

        #walk
        walk_edges = pd.read_csv(PED_EDGES_PATH)
        walk_nodes = pd.read_csv(PED_NODES_PATH)

        pt_nodes, pt_edges, pt_node_name_map = self.rename_nodes(pt_nodes, pt_edges, 'id_int', 'to_int', 'from_int')
        drive_nodes, drive_edges, drive_node_name_map=self.rename_nodes(drive_nodes, drive_edges, 'id', 'to', 'from')
        walk_nodes, walk_edges, walk_node_name_map=self.rename_nodes(walk_nodes, walk_edges, 'id', 'to', 'from')
        cycle_nodes, cycle_edges, cycle_node_name_map=self.rename_nodes(cycle_nodes, cycle_edges, 'id', 'to', 'from')

        network_dfs={
            'driving': {'edges':drive_edges, 'nodes': drive_nodes, 'node_name_map': drive_node_name_map} ,
            'pt': {'edges':pt_edges, 'nodes': pt_nodes, 'node_name_map': pt_node_name_map},
            'walking': {'edges':walk_edges, 'nodes': walk_nodes, 'node_name_map': walk_node_name_map},
            'cycling': {'edges':cycle_edges, 'nodes': cycle_nodes, 'node_name_map': cycle_node_name_map}
            }
        
        # Create graphs & portal links

        for osm_mode in ['driving', 'walking', 'cycling']:
            G = nx.Graph()
            for i, row in network_dfs[osm_mode]['edges'].iterrows():
                G.add_edge(
                    row['from_node_id'],
                    row['to_node_id'],
                    weight = (row['distance']/SPEEDS_MET_S[osm_mode]) / 60,
                    attr_dict = {'type' : osm_mode}
                )
            network_dfs[osm_mode]['graph'] = G

        G_pt = nx.Graph()
        for i, row in network_dfs['pt']['edges'].iterrows():
            G_pt.add_edge(
                row['from_node_id'],
                row['to_node_id'],
                weight = row['weight'],
                attr_dict = {'type' : pandana_link_types[row['net_type']]}
            )
            network_dfs['pt']['graph'] = G_pt

        # Find routes
        lon_lat_list = [
            [shape(f['geometry']).centroid.x, shape(f['geometry']).centroid.y] for f in all_zones_shp['features']
        ]
        closest_nodes = {}
        for net in network_dfs:
            closest_nodes[net] = []
            kdtree_nodes = spatial.KDTree(np.array(network_dfs[net]['nodes'][['x','y']]))
            for i in range(len(lon_lat_list)):
                _, c_nodes = kdtree_nodes.query(lon_lat_list[i], 10)
                closest_nodes[net].append(list(c_nodes))

        ext_route_costs = {}

        for mode in network_dfs:
            ext_route_costs[mode] = {}
            for z in range(len(all_zones_shp['features'])):
                print(mode+ ' ' +str(z))
                ext_route_costs[mode][all_zones_geoid_order[z]] = {}
                for p in range(len(portals['features'])):
                    ext_route_costs[mode][all_zones_geoid_order[z]][p] = {}
                    node_route_z2p = self.find_route_multi(
                        closest_nodes[mode][z],
                        ['p' + str(p)],
                        network_dfs[mode]['graph'],
                        'weight'
                    )

                    if node_route_z2p:
                        route_net_types = [
                            network_dfs[mode]['graph'][
                            node_route_z2p[i]][
                                node_route_z2p[i+1]
                            ]['attr_dict']['type'] for i in range(len(node_route_z2p) - 1)]
                        route_weights = [
                            network_dfs[mode]['graph'][
                                node_route_z2p[i]][
                                    node_route_z2p[i+1]
                                ]['weight'] for i in range(len(node_route_z2p) - 1)]
                        for l_type in ['walking', 'cycling', 'driving', 'pt', 'waiting']:
                            ext_route_costs[mode][all_zones_geoid_order[z]][p][l_type] = sum(
                                [route_weights[l] for l in range(len(route_weights)) if route_net_types[l] == l_type]
                            )
                    else:
                        for l_type in ['walking', 'cycling', 'driving', 'pt', 'waiting']:
                            ext_route_costs[mode][all_zones_geoid_order[z]][p][l_type] = 10000
        
        # save the results        
        json.dump(ext_route_costs, open(self.ROUTE_COSTS_PATH, 'w'))
