#!/usr/bin/env bash

# Description:	Automatic build process of my-app
# Author:		Guy Ziv
# Date:			2021, JUN, 14

# To Do:
# 1. get pom.xml as an argument
# 2. Log not only mvn commands (also mkdir for example)
# 3. On error, display logs path
# 4. If can't find get_jar_info()'s f_[vars], exit with error

###############################################################################
# GLOBAL VARIABLES
###############################################################################
prerequisites=("java" "mvn" "docker")
app_name="my-app"
log_dir="logs"
app_path="/home/ziguy/tmp/rafael/02/maven-hello-world/${app_name}"
flag_logging=false # true|false
dockerFile="dockerFile"

###############################################################################
# MAIN
###############################################################################
function main(){
	check_prerequisites "${prerequisites[@]}"
	check_log_dir "${log_dir}"

	jar_path=$(get_jar_info)
    compile || error "Failed on compile stage"
    package || error "Failed on package stage"
    create_artifact || error "Failed on create_artifact stage"
    create_docker_image || error "Failed on create_docker_image stage"
    # Create a docker image  containing the artifact (use Dockerfile)
    # Push the docker image that was created in the previous step to Docker Hub
    # Download and run the docker image.
	

	exit 0
}



###############################################################################
# FUNCTIONS
###############################################################################
function error(){
	echo -e "\e[1;31m  [-E-] $@\e[0m"
	exit 1
}


function introduce(){
	echo -e "\n\n========================================="
	echo "  $1"
	echo "========================================="
}


function logger(){
	[[ $flag_logging == "true" ]] && echo --log-file "${log_dir}/${app_name}_$1.log"
}


function check_prerequisites(){
	bad_commands=()

	while [[ $1 ]]; do
		printf "Checking for $1..."
		[[ ! `command -v $1` ]] && bad_commands+=("$1")
		echo
		shift
	done

	if [[ ${#bad_commands[@]} -gt 0 ]]; then
		error "Found the following missing dependencies. Please install them and try again:\n${bad_commands[*]}"
	fi

	echo "All dependencies are ready."
}


function check_log_dir(){
	dir=$1
	if [[ ! -d "$dir" ]]; then
		mkdir $dir 2>/dev/null || error "Failed creating log directory: $dir"
	fi
}


function compile(){
	introduce "clean"
	mvn clean $(logger "clean")
	cd $app_path
	introduce "compile"
	mvn compile $(logger "compile")
}


function package(){
	introduce "package"
	mvn package $(logger "package")
}


function get_tag_value(){
	tag=$1
	text=$2
	echo $text | grep -oPm1 "(?<=<$tag>)[^<]+"
}


function get_jar_info(){
	header=$(head pom.xml)
	f_name=$(get_tag_value "name" "$header")
	f_version=$(get_tag_value "version" "$header")
	f_packaging=$(get_tag_value "packaging" "$header")
	file_name=${f_name}-${f_version}.${f_packaging}

	if [[ $1 == "name" ]]; then
		echo $f_name
	elif [[ $1 == "version" ]]; then
		echo $f_version
	elif [[ $1 == "packaging" ]]; then
		echo $f_packaging
	else
		echo "target/${file_name}"
	fi
}


function create_artifact(){
	introduce "create_artifact"
	mvn -X install:install-file \
	-Dfile="${jar_path}" \
	-DgroupId="com.mycompany.app" \
	-DartifactId="greetings" \
	-Dversion=$(get_jar_info "version") \
	-Dpackaging=$(get_jar_info "packaging") \
	-DgeneratePom=true

#mvn dependency:list #check available dependencies

# dependency syntax (to put in pom.xml)
# 	<dependency>
#   <groupId>aGroupId</groupId>
#   <artifactId>aArtifactId</artifactId>
#   <version>1.0.12a</version>
# </dependency>
}


function create_docker_image(){
	introduce "create_docker_image"
	dockerFile=${app_name}.dockerFile
	cat << heredoc >${dockerFile}
FROM openjdk:7
MAINTAINER Guy Ziv guyziv84@gmail.com
COPY ${jar_path} /usr/src/${app_name}/
WORKDIR /usr/src/${app_name}
CMD ["java", "-jar", "/usr/src/${app_name}/${jar_path}"]
heredoc

	docker build -f ${app_name}.dockerFile -t ${app_name} .
	docker save ${app_name} -o ${app_name}.dockerImage
}
main
