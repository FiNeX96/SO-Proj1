#!/bin/bash
declare -A options=()  # associative array where the options/arguments will be stored
declare -A Rbytes=()   # associative array where Rbytes will be stored for each PID
declare -A Wbytes=()   # associative array where Wbytes will be stored for each PID
declare -A processinfo=() # associative array where the info of each process will be stored
i=0 # variable used to exit out of program if wrong arguments are given
regexnumber=^[0-9]*$            			             # regex for numbers
regexletras=^[a-zA-Z]+$ 	   			                 # regex for letters
reverse=0                                                # variable used to check if -r was given
sortonwrite=0                                            # variable used to check if -w was given



processes=$(ps -e)
pids=$(echo "$processes" | tail -n +2 | awk '{ print $1}')  # get the pids from the processes
mapfile -t arraypids < <(echo "${pids}") # put all the pids in the array arraypids
unset 'arraypids[-1]' # the ps -e process itself shouldnt be stored in the array,

function Arguments_guide(){
	echo "+----------+-------------------------------------------------+------------------------------+"
    echo "|  Option  |                  Description                    |             Example          |"
    echo "+----------+-------------------------------------------------+------------------------------+"
    echo "| -c       | Search processes by name ( regular expression)  |       -c bash                |"
    echo "| -s       | Search processes started after a certain date   |       -s \"Sep 20 10:00\"      |"
    echo "| -e       | Search processes started before a certain date  |       -e \"Dec 13 19:24\"      |"
	echo "| -u       | Search processes by user                        |       -u joão                |"
	echo "| -m       | Search processes with a higher PID than the arg |       -m 10                  |"
	echo "| -M       | Search processes with a lower PID than the arg  |       -M 100                 |"
	echo "| -p       | Search a specific number of processes           |       -p 25                  |"
	echo "| -r 	   | Sort the table by reverse order                 |   -r (arguments are ignored) |"              
	echo "| -w       | Sort the table by write values                  |   -w (arguments are ignored) |"               
    echo "+----------+-------------------------------------------------+------------------------------+"
	echo "|By default the table is sorted by read values decreasingly                                 |"
	echo "|The last argument must be a number -> time to wait between reads of the processes	    |"
	echo "|The following date months are accepted : Jan/Feb/Mar/Apr/May/Jun/Jul/Aug/Sep/Oct/Nov/Dec   |"
	echo "+-------------------------------------------------------------------------------------------+"
}
function Argument_checker(){
while getopts "c:s:e:u:m:M:p:rwh" option; do
	OPTARG=$(echo $OPTARG | cut -d '"' -f 1) # to be able to have the whole date as a argument , the function 
	#had to be called with $@\" , which in turn would give the arguments a double quote at the end , so this line 
	#removes the double quote
	if [[ -z "$OPTARG" ]]; then
        options[$option]="empty"  # if the argument to the option is empty , it is stored as "empty"
	else 
        options[$option]=$OPTARG  # if the argument to the option is not empty , it is stored in the associative array
	fi
    case $option in	
	h)                     # help function
		Arguments_guide
		exit 1
		;;
	c)                     # search by process name (COMM)
	    opcao=${options['c']}
		if [[ $opcao == 'empty' || ! $opcao =~ $regexletras ]]; then
			echo "Error: -c option requires an argument thats not a number or no argument was given!"
			echo "Execute script with -h option for extra help"
			i=1;
		fi
		;;
	s)  				   # search by start time (date))
	    opcao=${options['s']}
		if ! date -d "$opcao" > /dev/null 2>&1 ; then
			echo "Error: Invalid date (double quotes are needed) or no date was given at all!"
			echo "Execute script with -h option for extra help"
			i=1;
		    fi
		;;
	e)					  # search by end time (date)
	    opcao=${options['e']}
			if ! date -d "$opcao" > /dev/null 2>&1 ; then
			echo "Error: Invalid date (double quotes are needed) or no date was given at all!"
			echo "Execute script with -h option for extra help"
			i=1;
		    fi
			;;
	u)  					# search by user (USER)
		
	    opcao=${options['u']}
		if [[ $opcao == 'empty' ||  $opcao =~ $regexnumber ]]; then
			echo "Error: -u option requires a valid username !!! "
			echo "Execute script with -h option for extra help"
			i=1;
		fi
		;;
	m ) 				# search by higher PID than the argument
	   opcao=${options['m']}
	   if [[ $opcao == 'empty' ||  $opcao =~ $regexletras  ]]; then
	       echo "Error: -m requires a argument that is a number"
		   echo "Execute script with -h option for extra help"
		   i=1;
	   fi
	   ;;
    M )    		        # search by lower PID than the argument
	   opcao=${options['M']}
	    if [[ $opcao == 'empty' ||  $opcao =~ $regexletras  ]]; then
	       echo "Error: -M requires a argument that is a number"
		   echo "Execute script with -h option for extra help"
		   i=1;
        fi
		;;
	p )                # search a specific number of processes
	    opcao=${options['p']}
		if [[ $opcao == 'empty' ||  $opcao =~ $regexletras ]]; then
			echo "Error: -p option requires a number or no argument was given!"
			echo "Execute script with -h option for extra help"
			i=1;
        fi
	    ;;
	r )                # sort the table by reverse order
	    reverse=1;
	    ;;
	w)                 # sort the table by write values
	    sortonwrite=1;
	    ;;
	* )
		echo "Error: Invalid option !"
		echo "Execute script with -h option for extra help"
		i=1;
    esac
done

LastArg=$(echo ${@: -1} | cut -d '"' -f 1) # its easier to assign the last argument ( sleep time ) to a variable

if  [[ ! $LastArg =~ $regexnumber ]]; then  # ensure that the sleep time is a positive integer
	echo "Error: The last argument must be a number ( time to wait between reads!)"
	echo "Execute script with -h option for extra help"
	i=1;
fi

# if both a starting date and a ending date are provided, make sure that the start date is before the end date
if [[ -v options[s] && -v options[e] ]]; then
	    datestart=$(date -d "${options['s']}" +%s)
        dateend=$(date -d "${options['e']}" +%s)
		if [[ $datestart -gt $dateend ]]; then
			echo "Error: The start date must be before the end date"
			i=1;
	    fi
fi 
penultimate_argument=$(echo ${@: -2} | cut -d ' ' -f 1 | cut -d '-' -f 2 | tr -d ' ' ) # the penultimate argument is the one before the last one
## Check if the last argument being provided is an option's argument. It shouldnt, it should be the sleep time.
if [[ $i != 1 ]]; then 
   ## If there arent any errors with the arguments so far, check if the last argument is an option argument
	if [[ -v options[$penultimate_argument] || -z "options[$penultimate_argument]" ]]; then
	 	if [[ $penultimate_argument != 'r' && $penultimate_argument != 'w' ]]; then # if the penultimate argument is not the -r or -w option (these dont need arguments)
    	echo "Error: The last argument is the argument to the option -$penultimate_argument , not the sleep time!!"
		echo "Example of correct usage: ./rwstat.sh -$penultimate_argument \"-$penultimate_argument argument\" $((1 + $RANDOM % 10))"
		i=1;
		fi
	fi
fi

}
     
function get_data(){	
	tempo=$1
	for item in "${arraypids[@]}"; do  # for each pid in the array
		if [[ -r /proc/$item/status && -r /proc/$item/io ]]; then # if the files exist and are readable
		pid=$item
		Rbytes[$pid]=$( cat /proc/$item/io | awk '{print $2}' | head -n 1  ) # get inicial rchar
		wbytes[$pid]=$( cat /proc/$item/io | awk '{print $2}' | head -n 2 | head -n 1  )  # get inicial wchar
	   fi	
	done

	sleep $tempo
	
	for item in "${arraypids[@]}"; do
	if [[ -r /proc/$item/status && -r /proc/$item/io ]]; then 	
	    pid=$item
		comm=$( cat /proc/$pid/comm)  	 # get the comm ( name of process )
		utilizador=$(ps -o user= -p $pid)   # get the user
		date=$(ps -o lstart= -p $pid | cut -d ' ' -f 2,3,4,5 | cut -d ':' -f 1,2) # get the date in the correct format
		Rbytes2=$(cat /proc/$item/io | awk '{print $2}' | head -n 1  )  # get final rchar
		Wbytes2=$(cat /proc/$item/io | awk '{print $2}' | head -n 2 | head -n 1 ) # get final wchar
		rbytesdiff=$((Rbytes2-Rbytes[$pid])) # get the difference between the initial and final rchar
		wbytesdiff=$((Wbytes2-Wbytes[$pid])) # get the difference between the initial and final wchar
		rater=$((rbytesdiff/tempo)) # get the rate of read bytes
		ratew=$((wbytesdiff/tempo)) # get the rate of write bytes
		date_in_seconds=$(date -d "$date" +%s) #convert date to seconds

		if [[ -v options[c] && ! $comm =~ ${options['c']} ]]; then
			continue   # search by name ( regular expression )
		fi

		# -v = true if variable is set ( has a value)

		if [[ -v options[s] ]]; then  #search by minimum start date ( -s option )
			start=$(date -d "${options['s']}" +%s)
			if [[ $date_in_seconds -lt $start ]]; then
				continue # if the date is less than the given date, skip it
			fi
		fi

		if [[ -v options[e] ]]; then  # search by maximum start date ( -e option)
		   	end=$(date -d "${options['e']}" +%s)
			if [[ $date_in_seconds -gt $end ]]; then
				continue # if the date is greater than the given date, skip it
			fi
		fi

		if [[ -v options[u] && ! $utilizador =~ ${options['u']} ]]; then
			continue   # if the user doesnt match with the given user, skip it
		fi

		if [[ -v options[m] && $pid -lt ${options['m']} ]]; then
			continue  # if the pid is outside the given range, skip it
	    fi

		if [[ -v options[M] && $pid -gt ${options['M']} ]]; then
				continue    # if the pid is outside the given range, skip it
		fi
        # if the process passes all verification, put its print information in the array
		processinfo[$pid]=$(printf "%-27s	%-10s	%-5i	%-10i	%-10i	%-10i	%-10i	%-20s\n" "$comm" "$utilizador" "$pid" "$rbytesdiff" "$wbytesdiff" "$rater" "$ratew" "$date")
	fi
	done 
	prints
}


function prints() {
	#print the header
	printf "%-27s	%-10s	%-5s	%-10s	%-10s	%-10s	%-10s	%-20s \n" "COMM" "USER" "PID" "RBYTES" "WBYTES" "RATER" "RATEW" "DATE"
    if ! [[ -v options[p] ]]; then   # if the -pa option is not provided, print all the processes
        p=${#processinfo[@]}
    #Number of processes to print
    else
        p=${options['p']}   # if the -p option is provided, print the number of processes given by the user
    fi
    if [[ -v options[w] && ! -v options[r] ]]; then
        #Rate W decreasingly
        printf '%s \n' "${processinfo[@]}" | sort -rn -k7  | head -n $p 
	
    elif [[ -v options[w] && -v options[r] ]]; then
        # RateW increasingly
        printf '%s \n' "${processinfo[@]}" | sort -n -k7  | head -n $p 
	
    elif [[ -v options[r] && ! -v options[w] ]]; then
		# RateR increasingly
		printf '%s \n' "${processinfo[@]}" | sort -n -k6 |  head -n $p 
    else
		# RateR decreasingly
        printf '%s \n' "${processinfo[@]}" | sort -rn -k6 | head -n $p
    fi
}
if [[ $# == 0 ]]; then  # ensure atleast one argument must be passed ( the sleep time )
    echo "Atleast one argument must be passed ( time to wait between reads!)"
    echo "Execute script with -h option for extra help"
	i=1;
fi
Argument_checker "$@\""
if [[ $i == 1 ]] ; then
	exit 1
fi  # if there is an error with the arguments, exit the script

get_data ${@: -1}  # call function with last argument ( time to wait between reads )


