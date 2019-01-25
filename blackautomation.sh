export JAVA_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/jdk1.8.0_131
export MAVEN_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/apache-maven-3.5.0
export PROTEX_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/blackduck/protexIP
export PATH=$MAVEN_HOME/bin:$PATH
export PATH=$JAVA_HOME/bin:$PATH
export PATH=$PROTEX_HOME/bin:$PATH

echo "Scan ID: $scanID" 
echo "Application Name: $Appl_Name"
echo "Version: $Version"

#ART_URL=http://uat.art.com:8081/artifactory
#ART_URL=http://dev.art.com:8081/artifactory
ART_URL=http://prod.art.com:8081/artifactory

#REPO=msh_maven_oss
REPO=maven_oss
#REPO=dmh_maven_oss
#APP_CODE=MSH
APP_CODE=dmh

#USERID=<usdid>
#PASSWORD=<password>
USERID=<psdid>
PASSWORD=<password>
#USERID=<dsid>
#PASSWORD=<password>

if [ -f ${WORKSPACE}/${APP_CODE}_Report.txt ] ; then 
	rm -rf ${WORKSPACE}/${APP_CODE}_Report.txt
fi
BinaryPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/$APP_CODE/lib
cd $BinaryPath
java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/center-1.0-executable.jar https://CodeCenter.com/ <uid> <password> "$Appl_Name" $Version $scanID >> /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}_report.log 2>&1


#BinaryPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/CDH
#cd $BinaryPath

#java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/collect-destpath-jar-list.jar ${BinaryPath}
#dos2unix JarPathList.txt
#rm -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/ApprovedBinaryList_NOSPL.txt
#awk '{ sub("\r$", ""); print }' /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/ApprovedBinaryList.txt > /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/ApprovedBinaryList_NOSPL.txt

while read binaryname
do	
rm -rf ${WORKSPACE}/MVN_CURL_OUT.log
echo "Checkin the binary existance of $binaryname" 
binaryname=${binaryname%$'\r'}
curl -u ${USERID}:${PASSWORD} -X GET "$ART_URL/api/storage/$REPO/$binaryname" >> ${WORKSPACE}/MVN_CURL_OUT.log
EXIT_STATUS=$?
if [ ${EXIT_STATUS} == 0 ]
then
ERRORS=`cat ${WORKSPACE}/MVN_CURL_OUT.log | grep "errors" | wc -l`
UNBL_FIND_ART=`cat ${WORKSPACE}/MVN_CURL_OUT.log | grep "Unable to find item" | wc -l`
URI_VAL=`cat ${WORKSPACE}/MVN_CURL_OUT.log | grep "uri" | wc -l`
DOWNLOAD_URI=`cat ${WORKSPACE}/MVN_CURL_OUT.log | grep "downloadUri" | wc -l`
if [[ ${ERRORS} == 0 && ${UNBL_FIND_ART} == 0 ]]
then
expr $URI_VAL > 1
EXPR_URI_VAL=`echo $?`
expr $DOWNLOAD_URI > 1
EXPR_DOWNLOAD_URI=`echo $?`
else 
echo "It's a new artifact"
fi
	if [[ ${ERRORS} == 1 && ${UNBL_FIND_ART} == 1 ]]
	then
		echo "$binaryname is a new artifact"    
        binaryname=${binaryname%$'\r'}
		curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/list/$REPO/$binaryname" -T $binaryname
		DEP_POM_FILE=`echo $binaryname | sed 's/.jar$/.pom/' | tr -d [:blank:]`
        	if [ -f $DEP_POM_FILE ]
            then  
            binaryname=${binaryname%$'\r'}
			curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/list/$REPO/$DEP_POM_FILE" -T $DEP_POM_FILE
		    else
            echo "$DEP_POM_FILE not found"
            fi
        echo "Tagging the appcode $APP_CODE for new artifact $binaryname"
        binaryname=${binaryname%$'\r'}
		curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=${APP_CODE}"
	elif [[ ${EXPR_URI_VAL} == 0 && ${EXPR_DOWNLOAD_URI} == 0 ]]
	then
		echo "$binaryname is already existing tagging the appcode"
			if [ -f ${WORKSPACE}/Appcodedetails.txt ] ; then 
				rm -rf ${WORKSPACE}/Appcodedetails.txt
			fi
            binaryname=${binaryname%$'\r'}
			curl -X GET -g -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode" > ${WORKSPACE}/Appcodedetails.txt
			AppCodevalue=`cat ${WORKSPACE}/Appcodedetails.txt | grep '"AppCode"' | awk -F ':' '{print $2}' |tr -d , | sed 's/[][]//g' | tr -d '\"'|sed 's/^ *//'|sed  's/ /,/g'|sed 's/,$//'`
			echo $AppCodevalue
       
			if [ -z "$AppCodevalue" ]
			then
                binaryname=${binaryname%$'\r'}
				curl -X PUT -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=${APP_CODE}"
				echo "Adding APP code for the first time to the  Property updated"
			else
				#echo "Version Already distributed to Env $AppCodevalue "
				IFS=',' read -r -a array <<< "$AppCodevalue"
				for index in "${!array[@]}"
				do
					if [ ${array[index]} = ${APP_CODE} ];
					then
					echo " Package has been already associated with Appcode . Please check"
					else
					echo "Adding AppCode property to the existing one "
					Appvalue="$APP_CODE,$AppCodevalue"
                    binaryname=${binaryname%$'\r'}
					curl -X PUT -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=$Appvalue"
					echo "Adding Appcode to the property, Property updated"
					fi
				done
			fi
			rm -rf ${WORKSPACE}/Appcodedetails.txt
	else
		echo "Please check the ${WORKSPACE}/MVN_CURL_OUT.log"
	fi
else
	echo "Please check the ${WORKSPACE}/MVN_CURL_OUT.log"
fi
done < /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/dmh/lib/JarPathList.txt

#cd /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/
#java -jar jenkins-cli.jar -auth e623869:$e623869 -s http://dev-sdpdevops-je1.statestr.com:8080/jenkins disable-job Nagendra/Protex_Promote_JOB

#if [ -f /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/BinaryList.txt ]
#then

#    rm -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/$Appl_Name
    
#     rm -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/BinaryList.txt 
    
#    rm -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/get-components-from-CC-master/ApprovedBinaryList.txt
#fi
