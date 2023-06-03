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
	int nb_people <- 100;
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
	float target_year ;
	

	float initial_emission <- 182.0 ;
	float total_emission;
	float supply ;
	float demand ;
	float alpha ;
	float market_value ;
	float target_emission ;
	
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
		
		create government number: 1 {
			list thelist <-list (species_of (people)); 
               if(not empty(thelist)){
                  loop i from: 0 to: length (thelist) - 1 
                  { 
    	              ask thelist at i{
    	              	total_supply <- total_supply + supply ;
    	              	total_demand <- total_demand + demand ;
    	              }
                  } 
         
                } 
			price <- alpha * (total_demand-total_supply) + price ;
			market_value <- total_supply * price ;
			target_year <- 10.0 ;
			target_emission <- 75.0 ;
			allowance_rate <- (initial_emission - target_emission)/(target_year * total_emission) ;
			
		}  
		
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
            //每十二个月更新一下allowance
    
            if (cycle > 0 and (cycle mod 12) = 0)
            {
      	       float av<-0.0;
      	 
      	       list thelist <-list (species_of (people)); 
               if(not empty(thelist)){
                  loop i from: 0 to: length (thelist) - 1 
                  { 
    	              ask thelist at i{av <- av + (demand - BaseDemand) / BaseDemand;}
                  } 
         
                } 
         
               av<- av/length(thelist);
               averageReduce <- (-100) * av; //this is the average amount households have reduced
               allowance <- (allowance - allowance * (target + sensitivity * (target - averageReduce)) / 100); //the second term adjusts the amount reduced depending on how far away the true reduction is from the target
               ask agents of_species household { BaseDemand <- demand; }
             }

             //更新allowance市价
      	     if (cycle > 4) {
                //according to p(t+1)-pt=α(Dt-St) = p_t+1 = p_t + alpha * (dempandpool - allowpool_new)
                price <- price + alpha * (total_demand / nb_people - total_supply_new / nb_people);
             }
             total_supply <- total_supply_new ;
             total_supply_new <- 0.0 ;
             total_demand <- 0.0 ;
             // ensure the price stays positive / price cannot fall below 0.001 but can increase limitless
             price <- max ([ price, 0.001]) ;
      
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

species government {
	
}

species people skills:[moving] {
	rgb color <- #yellow ;
	building living_place <- nil ;
	building working_place <- nil ;
	int start_work ;
	int end_work  ;
	string objective ;
	point the_target <- nil ;
	
	float emission ;
	float allowance <- emission * allowance_rate ;
	float diff <- allowance - emission ;
	float demand ;
	float supply ;
	float reward ;
	list travel_mode ;
	float travel_distance ;
	float travel_speed ;
	float travel_time ;
	float carbon_cost ;
	float distance ;
		
	reflex time_to_work when: current_date.hour = start_work and objective = "resting"{
		objective <- "working" ;
		the_target <- any_location_in (working_place);
		distance <- location distance_to the_target ;
	}
		
	reflex time_to_go_home when: current_date.hour = end_work and objective = "working"{
		objective <- "resting" ;
		the_target <- any_location_in (living_place);
		distance <- location distance_to the_target ;
	} 
	 
	reflex move when: the_target != nil {
		do goto target: the_target on: the_graph ;
		list trave_mode <- 1 among['car', 'bus', 'bicycle'] ;
		if travel_mode = ['car']{
			carbon_cost <- 182.0 ;
			speed <- rnd(10.0, 50.0);
		}
		else if travel_mode = ['bus']{
			carbon_cost <- 25.0 ;
			speed <- rnd(1.0, 30.0) ; 
		}
		else if travel_mode = ['bicycle']{
			carbon_cost <- 0.0 ;
			speed <- rnd(1.0, 15.0) ;
		}
		else{
			carbon_cost <- 0.0 ;
			speed <- rnd(1.0, 5.0) ;
		}
		
		if the_target = location {
			the_target <- nil ;
			travel_time <- distance / speed ;
			emission <- carbon_cost * distance ;
		}
	}
	reflex go{
        diff <- allowance * number_persons - demand ;

        float noa <- abs(diff) ; // the value for "number of allowances" left after demand subtracted


        // if an agent needs to buy allowances, it shall buy them if available
        //如果这家需要买, 市场上有, 并且买得起
        if ((diff < 0.0) and (allowpool > noa) and (price * CarbonVal * noa < income * IncomePercentAvailable))
        {
            allowpool <- allowpool - noa ;//更新allowance池和需求池
            demandpool <- demandpool + noa ;
        }
	
	aspect base {
		draw circle(10) color: color border: #black;
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
	parameter "minimal speed" var: min_speed category: "People" min: 0.1 #km/#h ;
	parameter "maximal speed" var: max_speed category: "People" max: 10 #km/#h;
	
	output {
		display city_display type: 3d {
			species building aspect: base ;
			species road aspect: base ;
			species people aspect: base ;
		}
	}
}
