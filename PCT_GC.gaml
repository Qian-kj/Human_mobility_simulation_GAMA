/**
* Name: PCTGC
* Based on the internal empty template. 
* Author: Jiang
* Tags: 
*/


model PCTGC


/* Insert your model definition here */
global {
	file shape_file_buildings <- file("../includes/building.shp");
	file shape_file_roads <- file("../includes/road.shp");
	file shape_file_bounds <- file("../includes/bounds.shp");
	geometry shape <- envelope(shape_file_bounds);
	float step <- 10 #mn;
	date starting_date <- date("2019-09-01-00-00-00");
	int nb_people <- 10;
	int min_work_start <- 6;
	int max_work_start <- 8;
	int min_work_end <- 16; 
	int max_work_end <- 20; 
	
	float allowance_rate ;
	float total_supply ;
	float total_supply_new ;
	float total_demand ;
	float price ;
	float initial_price <- 0.1 ;
	float average_reduction ;
	float average_allowance ;	

	float initial_emission <- 182.0 ;
	float target_emission <- 75.0 ;
	float target_year <- 10.0 ;
	float total_emission ;
	float total_reward ;
	float alpha ;
	float market_value ;
	
	graph the_graph;
	
	init {
		create building from: shape_file_buildings with: [type::string(read ("NATURE"))] {
			if type="Industrial" {
				color <- #blue ;
			}
		}
		create road from: shape_file_roads ;
		the_graph <- as_edge_graph(road) ;
		
		list<building> residential_buildings <- building where (each.type="Residential");
		list<building> industrial_buildings <- building  where (each.type="Industrial") ;
		
		create people number: nb_people {
			start_work <- rnd (min_work_start, max_work_start);
			end_work <- rnd(min_work_end, max_work_end);
			living_place <- one_of(residential_buildings);
			working_place <- one_of(industrial_buildings);
			objective <- "resting";
			location <- any_location_in (living_place); 
		}
	}
	reflex carbon_marketing{
            //update annual allowance rate
            if (cycle > 1 and (cycle mod 12) = 0) {
      	       list thelist <-list (species_of (people)); 
               if(not empty(thelist)){
                  loop i from: 0 to: length (thelist) - 1 { 
    	              ask thelist at i{
    	              	total_supply_new <- total_supply_new + supply ;
    	              	total_demand <- total_demand + demand ;
    	              	total_emission <- total_emission + total_emission_per ;
    	              	total_reward <- total_reward + reward;
    	              }
                  } 
                } 
         
         	   price <- price + alpha * (total_demand - total_supply_new) ;
         	   total_supply <- total_supply_new ;
         	   total_supply_new <- 0.0 ;
         	   total_demand <-0.0 ;
         	   price <- max ([ price, 0.001]) ;
         	   
         	   market_value <- total_supply * price ;
			   target_year <- 10.0 ;
			   allowance_rate <- (initial_emission - target_emission)/(target_year * 1) ;
//         	   allowance_rate <- (initial_emission - target_emission)/(target_year * total_emission/nb_people) ;
//               av <- av/length(thelist) ;
//               averageReduce <- (-100) * av ; //this is the average amount households have reduced
//               
//               ask agents of_species household { BaseDemand <- demand ; }
             }
    }
}

species building {
	string type; 
	rgb color <- #gray  ;
	
	aspect base {
		draw shape color: color ;
	}
}

species road  {
	rgb color <- #black ;
	aspect base {
		draw shape color: color ;
	}
}

species people skills:[moving] {
	rgb pcolor <- #yellow ;
	building living_place <- nil ;
	building working_place <- nil ;
	int start_work ;
	int end_work  ;
	string objective ;
	point the_target <- nil ;
	
	float emission ;
	float total_emission_per ;
	float allowance <- emission * allowance_rate ;
	float availability ;
	float diff <- allowance - total_emission_per;
	float demand ;
	float supply ;
	float reward ;
	string travel_mode ;
	float travel_distance ;
	float travel_speed ;
	float travel_time ;
	float carbon_cost ;
	float distance ;
	float total_distance ;
	
	reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
		objective <- "working" ;
		the_target <- any_location_in (working_place);
	}
		
	reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
		objective <- "resting" ;
		the_target <- any_location_in (living_place);
	} 
	 
	reflex move when: the_target != nil {
		do goto target: the_target on: the_graph ;
//		speed <- 1000.0 ;
//		carbon_cost<-1200.0 ;
//		unknown trave_mode <- 1 among['car', 'bus', 'bicycle'] ;
		travel_mode <- rnd_choice(["car"::0.25,"bus"::0.25,"bicycle"::0.25,"walk"::0.25]) ;
		if travel_mode = 'car'{
			carbon_cost <- 182.0 ;
			speed <- rnd(10.0, 50.0) #km / #h;
		}
		else if travel_mode = 'bus'{
			carbon_cost <- 25.0 ;
			speed <- rnd(10.0, 30.0) #km / #h; 
		}
		else if travel_mode = 'bicycle'{
			carbon_cost <- 0.0 ;
			speed <- rnd(10.0, 15.0) #km / #h;
		}
		else if travel_mode = 'walk'{
			carbon_cost <- 0.0 ;
			speed <- rnd(1.0, 5.0) #km / #h;
		}
		distance <- speed * step * 10 ; //km
		emission <- carbon_cost * distance ;
		total_emission_per <- total_emission_per + emission ;
		reward <- allowance*distance - emission ;
			
		if the_target = location {
			the_target <- nil ;
			travel_time <- distance / speed ;
			
			}
		}
	
	reflex carbon_trading{
		if diff < 0.0{
			demand <- diff ;
		}
		else {
			supply <- diff ;
		}

        float noa <- abs(diff) ; // the value for "number of allowances" left after demand subtracted
        // if an agent needs to buy allowances, it shall buy them if available
        if ((diff < 0.0) and (total_supply > noa))
        {
            total_supply <- total_supply - noa ;
            total_demand <- total_demand + noa ;
        }
		
		// if there is no allowance
		else if ((diff < 0.0) and (total_supply < noa))
        {
            pcolor <- #red;
            total_demand <- total_demand + noa ;
        }
        
        // if there is extra allowance
        else if (diff > 0.0)
        {
        	total_supply <- total_supply + noa ;
        }
	}
	aspect base {
		draw circle(10) color: pcolor border: #black;
	}
}


experiment road_traffic type: gui {
	parameter "Shapefile for the buildings:" var: shape_file_buildings category: "GIS" ;
	parameter "Shapefile for the roads:" var: shape_file_roads category: "GIS" ;
	parameter "Shapefile for the bounds:" var: shape_file_bounds category: "GIS" ;	
	parameter "Number of people agents" var: nb_people category: "People" ;
	parameter "Earliest hour to start work" var: min_work_start category: "People" min: 2 max: 8;
	parameter "Latest hour to start work" var: max_work_start category: "People" min: 8 max: 12;
	parameter "Earliest hour to end work" var: min_work_end category: "People" min: 12 max: 16;
	parameter "Latest hour to end work" var: max_work_end category: "People" min: 16 max: 23;

	
	output {
		display city_display type: 3d {
			species building aspect: base ;
			species road aspect: base ;
			species people aspect: base ;
		}
		display chart_display refresh: every(10#cycles)  type: 2d {
			chart "Carbon Performance" type: series size: {0.5, 0.5} position: {0, 0} {
				data "Mean carbon emission per capita" value: mean (people collect each.total_emission_per) style: line color: #green ;
				data "Total carbon emission" value: total_emission style: line color: #red ;
				}
			chart "Carbon Market" type: series size: {0.5, 0.5} position: {0.5, 0} {
				data "Price" value: price style: line color: #green ;
				}
			chart "Reward" type: series size: {0.5, 0.5} position: {0, 0.5} {
				data "Personal reward" value: mean (people collect each.reward) style: line color: #green ;
				data "Total reward" value: total_reward style: line color: #blue ;
				}
//			chart "People Object" type: pie style: exploded size: {0.5, 0.5} position: {0, 0.5}{
//				data "Working" value: people count (each.objective="working") color: #magenta ;
//				data "Resting" value: people count (each.objective="resting") color: #blue ;
//				}
			chart "Travel Mode" type: pie style: exploded size: {0.5, 0.5} position: {0.5, 0.5}{
				data "Bus" value: people count (each.travel_mode="bus") color: #magenta ;
				data "Car" value: people count (each.travel_mode="car") color: #blue ;
				data "Bicycle" value: people count (each.travel_mode="bicycle") color: #red ;
				data "Walk" value: people count (each.travel_mode="walk") color: #yellow ;
			}
		}
	}
}
