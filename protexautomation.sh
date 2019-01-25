#!/bin/bash
set +x

export JAVA_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/jdk1.8.0_131
export MAVEN_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/apache-maven-3.5.0
export PROTEX_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/blackduck/protexIP
export NODE_HOME=/usr/local/web/arqe/node-v8.12.0-linux-x64/
export PATH=$MAVEN_HOME/bin:$PATH
export PATH=$JAVA_HOME/bin:$PATH
export PATH=$PROTEX_HOME/bin:$PATH
export PATH=$NODE_HOME/bin:$PATH

echo "==========================[START]Killing kie-server process===================="
process_Id=$(ps -ef | grep "kie-server" | grep 8080 | awk '{print $2}')
if [[ $process_Id -gt 0 ]]
then
	echo "Killing the kie-server process ID $process_Id"
    kill -9 $process_Id
fi
echo "==========================[END]Killing kie-server process===================="

echo "==========================[START]Removing env.properties===================="
if [ -f ${WORKSPACE}/env.properties ]
then
	echo "removed env.properties"
    rm -rf ${WORKSPACE}/env.properties
fi
echo "==========================[END]Removing env.properties===================="


echo "================================[START]Jenkins Job Status Check================================="

cd /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest
if [ ! -f "jenkins-cli.jar" ]
then
	wget http://dev.jenkins.com:8080/jenkins/jnlpJars/jenkins-cli.jar
fi



java -jar jenkins-cli.jar -auth <id>:<pass>9 -s http://dev.jenkins.com:8080/jenkins get-job Nagendra/Protex_Promote_JOB > ${WORKSPACE}/config_job_xml_output.txt

cd /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/ 
status_of_jenkins_job=`java -jar JenkinsJobStatus.jar ${WORKSPACE}/config_job_xml_output.txt`
echo $status_of_jenkins_job

if [ "$status_of_jenkins_job" == "true" ]
then

  echo "=====Job is Disabled====="
  curl -u <id>:<pass> -X DELETE "http://artifactory.com:8081/artifactory/Pre-promotion_staging/"$Appl_Name"/"
  
  echo "Cleaned up Staging repo for $Appl_Name"

else

  echo "=====Job is Enabled. Aborting it======"
  curl -X POST -u e623869:$e623869 http://dev.jenkins.com:8080/jenkins/job/Nagendra/job/Protex_Upload_JOB/lastBuild/stop
  curl -u psdpart:AP2fHYiyLxnKRccai7TMh68iB3o -X DELETE "http://artifactory.com:8081/artifactory/Pre-promotion_staging/"$Appl_Name"/"
fi
echo "================================[END]Jenkins Job Status Check================================="

FileFormat=`echo ${FilePath}|awk -F '/' '{print $NF}'|tr -d "[:blank:]"`
if [[ ${FileFormat} == *.xml ]]
then
	mkdir -p /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/"$Appl_Name"
	cd ${WORKSPACE}/local_sub_repo
	DestPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/"$Appl_Name"
	dirName=`dirname ${FilePath}`
	cd $dirName
	echo "dirName= $dirName"
	echo "DestPath  : $DestPath"
	mvn install  -f pom.xml  -gs settings.xml dependency:copy-dependencies -DoutputDirectory=${DestPath}
    if [[ $? != 0 ]]
    then
    echo "Failed to download dependencies, please check the pom.xml"
    exit 1
    fi
elif [[ ${FileFormat} == *.json ]]
then
	rm -rf ${WORSPACE}/Node_APP_Src
    echo "==========================[START]updating .npmrc file===================="
	echo "Current working directory $PWD"
	/usr/local/web/arqe/node-v8.12.0-linux-x64/bin/npm config set registry http://artifactory.com:8081/artifactory/api/npm/npmjs_omnia/
	echo "list files under workspace"
	echo "==========================[END]updating .npmrc file===================="

	echo "============[START]Initializing dest folder & copy package.json=========="
	mkdir -p ${WORKSPACE}/Node_APP_Src
	NodSrcPath=${WORKSPACE}/Node_APP_Src
	NodModPath=${NodSrcPath}/node_modules
	echo "NodModPath  : ${NodModPath}"
	echo "Package_json path ${FilePath}"
	cp -rf ${WORKSPACE}/local_sub_repo/${FilePath} ${NodSrcPath}
	if [[ $? != 0 ]]
	then
	echo "failed to copy package.json file to workspace"
	exit 1
	fi
	echo "============[END]Initializing dest folder & copy package.json=========="

	echo "======================[START]Downloading NPM packages================="
	cd ${NodSrcPath}
	/usr/local/web/arqe/node-v8.12.0-linux-x64/bin/npm install
	EXIT_STATUS=$?
	echo "exit status ${EXIT_STATUS}"
	if [[ ${EXIT_STATUS} != 0 ]]
	then
	echo "Failed in downloading the dependencies please check the package.json"
	exit 1
	else
	echo "Successfully downloaded the packages to Node_APP_Src/node_modules"
	fi
	echo "========================[END]Downloading NPM packages=================="

	echo "======================[START]Archiving the listed packages================="
	ls ./node_modules/ >> List.txt
	mkdir NPM_Pack_Dest
	Final_Dest_Path=${NodSrcPath}/NPM_Pack_Dest
	while read pkg
	do
	if [[ $pkg == @* ]]
	then
	ls ./node_modules/${pkg} >> ${pkg}_list.txt
	fi
	done < ${NodSrcPath}/List.txt
	cp -rf package.json /tmp/
	while read pkg
	do
	if [[ ${pkg} == @* ]]
	then
	while read spkg
	do
	cd ${NodModPath}/${pkg}/${spkg}
	/tmp/node-v8.14.0-linux-x64/bin/yarn pack
	mv *.tgz ${Final_Dest_Path}
	cd ${NodSrcPath}
	done < ${NodSrcPath}/${pkg}_list.txt
	else
	cd ${NodModPath}/${pkg}
	/tmp/node-v8.14.0-linux-x64/bin/yarn pack
	mv *.tgz ${Final_Dest_Path}
	cd ${NodSrcPath}
	fi
	done < ${NodSrcPath}/List.txt
else
	echo "Please mention the correct file format"
fi


echo "==========================[START]Getting application Project-ID===================="
java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/ProtexBDServices-1.0.jar "$Appl_Name" > output.txt
project_ID=`cat output.txt |grep "Project ID" | awk '{ print $3}'`
echo "Project ID is : $project_ID"
echo "==========================[END]Getting application Project-ID===================="

echo "==========================[START]Protex Initiate Scan===================="
cd $DestPath
bdstool --server http://server.com:8080 --user <is> --password <pass> login
bdstool new-project $project_ID
bdstool analyze
rm -rf output.txt
echo "==========================[END]Protex Initiate Scan===================="


scanId=$RANDOM
export scanID=$scanId
echo scanID=$scanId > ${WORKSPACE}/env.properties
echo "Appl_Name=$Appl_Name" >> ${WORKSPACE}/env.properties
echo "Version=$Version" >> ${WORKSPACE}/env.properties
cat ${WORKSPACE}/env.properties

echo "The Unique Scan ID for Project - $Appl_Name is $scanId"


############################################################################
BinaryPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/"$Appl_Name"/lib

cd ${WORKSPACE}/local_sub_repo/$dirName
mvn install  -f pom.xml  -gs /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/mvn_settings.xml  dependency:copy-dependencies -Dmdep.useRepositoryLayout=true -DoutputDirectory=${BinaryPath}

cd $BinaryPath

${JAVA_HOME}/bin/java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/collect-destpath-jar-list.jar ${BinaryPath}

awk '{ sub("\r$", ""); print }' /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/JarPathList.txt > /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/BinaryList.txt

while read binaryname
do	
	
	curl -u <is>:<pass> -X PUT "http://artifactory.com:8081/artifactory/Pre-promotion_staging/"$Appl_Name"/$binaryname;ScanId=$scanId" -T ./$binaryname
	
done < /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/BinaryList.txt

mailx -r user@email.com -s "TESTING: The Unique Scan ID for Project - $Appl_Name is $scanId" user@email.com user@email.com user@email.com

cd /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/
java -jar jenkins-cli.jar -auth <id>:<pass>http://dev.jenkin.com/jenkins enable-job Nagendra/Protex_Promote_job
