#!/bin/bash
set +x
export JAVA_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/jdk1.8.0_131
export MAVEN_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/apache-maven-3.5.0
export PROTEX_HOME=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/blackduck/protexIP
export PATH=$MAVEN_HOME/bin:$PATH
export PATH=$JAVA_HOME/bin:$PATH
export PATH=$PROTEX_HOME/bin:$PATH

if [[ $PromoteType == Install_Validate_Copy ]]
then
	echo "====================[START]Validation of parameters======================"
	if [[ ! -z $CodeCenter_Appl_Name && ! -z $Version && ! -z $APP_CODE && ! -z $GIT_REPO ]]
	then
		echo "Application Name: $CodeCenter_Appl_Name"
		echo "Version: $Version"
		echo "App_Code: $APP_CODE"
        echo "Git_Repo:$GIT_REPO"
		if [[ -z $scanID ]]
		then
			scanID=100
			echo "Scan ID: $scanID"
		else
			echo "Scan ID: $scanID"
		fi
	else  
		echo "These fields cannot be empty CodeCenter_Appl_Name/Version/Version/GIT_REPO"
		exit 1
	fi
	echo "====================[END]Validation of parameters======================"

	echo "==========================[START]Installation of Maven Binaries===================="
	if [ ! -d /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO} ]
		then
			mkdir -p /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}
		else
			echo "${APP_CODE}/${GIT_REPO} already exist under latest folder"
            rm -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}/*
	fi
	PropPoms=`echo ${FilePaths} | tr -d [:blank:]`
	IFS=',' read -r -a array <<< $PropPoms
	for index in "${!array[@]}"
	do
	FilePath=`echo ${array[index]}`
	FileFormat=`echo ${FilePath}|awk -F '/' '{print $NF}'|tr -d "[:blank:]"`
	if [[ ${FileFormat} == pom.xml ]]
	then
		cd ${WORKSPACE}/local_sub_repo
		DestPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}
		DestLibPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}/lib
		DestinationLibPath=`echo $DestLibPath`
		dirName=`dirname ${FilePath}`
		cd $dirName
		echo "dirName= $dirName"
		echo "DestPath  : $DestPath"
		echo "Copying settings.xml to current directory"
        
		
		if [ -f /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/settings.xml ]
		then
			echo "Copying Settings.xml to the ${DestPath}"
			cp -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/settings.xml .
		else
			echo " Setting.xml is not available in latest path"
			exit 1
		fi
		echo "Installing Maven dependencies in $DestPath"
		mvn dependency:resolve -Dmaven.test.skip=true -f pom.xml -gs ./settings.xml -Dm2.localRepository=${DestinationLibPath}
		if [[ $? != 0 ]]
		then
			echo "Failed to install dependencies, please check the pom.xml"
			exit 1
		fi
	elif [[ ${FileFormat} != pom.xml ]]
	then
		echo "Please give the correct pom.xml path including the pom.xml in FilePath value"
		exit 1
	else
		echo "Please give the correct value of ${FileFormat}"
		exit 1
	fi
	done
	echo "==========================[END]Installation of Maven Binaries===================="
	
	echo "==========================[START]Generation of BinaryList.txt===================="
	cd ${DestPath}
	if [ -f /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/whiltList.properties ]
	then
		cp /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/whiltList.properties .
		echo "Creating the BinaryList.txt file"
		${JAVA_HOME}/bin/java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/separate-binary-type-1.0.jar ${DestinationLibPath}
		if [[ $? != 0 ]]
		then
			echo "Failed to Generate BinaryList.txt file"
			exit 1
		fi
	else
		echo "whiltList.properties not available in the latest folder"
		exit 1
	fi
    awk '{ sub("\r$", ""); print }' ${DestPath}/BinaryList.txt > InstalledBinaryList.txt
	echo "==========================[END]Generation of BinaryList.txt===================="
	
	echo "========================[START]Copying BinaryList.txt==============================="
	export DestPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/$APP_CODE/$GIT_REPO
    BinaryPath=`echo $DestPath`
    echo $BinaryPath
	if [[ -d $BinaryPath ]]
	then
		echo "Binary installation exists"
		cd $BinaryPath
		if [[ -f $BinaryPath/BinaryList.txt && -d $BinaryPath/lib ]]
		then
			mv $BinaryPath/BinaryList.txt $BinaryPath/NspcBinaryList.txt
			if [[ -f $BinaryPath/NspcBinaryList.txt ]]
			then
				awk '{ sub("\r$", ""); print }' $BinaryPath/NspcBinaryList.txt > $BinaryPath/BinaryList.txt
			else
				echo "$BinaryPath/NspcBinaryList.txt is not found please check"
				exit 1
			fi
		else
			echo "$BinaryPath/BinaryList.txt or $BinaryPath/lib is not found please check"
			exit 1
		fi
	else
		echo "Cannot able to find installed binary folder under latest folder."
		echo "Please install dependencies using the Install_Validate_And_Copy option"
		exit 1
	fi
    echo "==============================[END]Copying BinaryList.txt==============================="
	
	echo "===================[START]Report Generation==============================================="
	cd $BinaryPath
	echo "Current working directory $PWD"
    rm -rf ApprovedBinaryList.txt NspcApprovedBinaryList.txt NspcBinaryList.txt UnMatchedBinaryList.txt UnApprovedBinaryList.txt InstalledBinaryList.txt $APP_CODE_*report.log
	$JAVA_HOME/bin/java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/center-1.0-executable.jar https://codecenter.com/ <username>" "<password>" "$APP_CODE/$GIT_REPO" "$CodeCenter_Appl_Name" "$Version" "$scanID" >> $BinaryPath/${APP_CODE}_${GIT_REPO}_report.log 2>&1
	if [ $? != 0 ]
	then
		echo "Problem in generating reports please check, please check below Codecenter jar error log"
		cat $BinaryPath/${APP_CODE}_${GIT_REPO}_report.log
		exit 1
	fi
    if [[ -f $BinaryPath/ApprovedBinaryList.txt ]]
    then
		awk '{ sub("\r$", ""); print }' $BinaryPath/ApprovedBinaryList.txt > $BinaryPath/NspcApprovedBinaryList.txt
    else
    	echo "Unable to find $BinaryPath/ApprovedBinaryList.txt"
		exit 1
    fi
	echo "===================[END]Report Generation==============================================="
	
	if [[ "$Upload_Artifactory_Env" == "PROD" ]]
	then
		ART_URL=http://prod.artifactory.com:8081/artifactory
		USERID=<username>
		PASSWORD=<password>
	elif [[ "$Upload_Artifactory_Env" == "UAT" ]]
	then
		ART_URL=http://uat.artifactory.com:8081/artifactory
		USERID=<username>
		PASSWORD=<password>
	else
		ART_URL=http://dev.artifactory.com:8081/artifactory
		USERID=<username>
		PASSWORD=<password>
	fi
	
	echo "===================[START]Uploading artifact and adding/appending AppCode==============================================="
	cd $BinaryPath/lib/
	while read binaryname
	do
		if [[ $binaryname == org/apache/maven/* ]]
		then
			REPO=$MAVEN_REPO
		elif [[ $binaryname == com/oracle/* || $binaryname == com/google/* || $binaryname == com/ibm/* ]]
		then
			REPO=$VENDOR_REPO
		elif [[ $binaryname == com/ssc/* || $binaryname == com/statestreet/* || $binaryname == com/statestr/* || $binaryname == com/stt/* ]]
		then
			REPO=$SSC_REPO
		else
			REPO=$OSS_REPO
		fi
	echo "$binaryname will be uploaded to $ART_URL/$REPO"
	rm -rf ${WORKSPACE}/MVN_CURL_OUT.log
	echo "Checkin the binary existance of $binaryname" 
	binaryname=${binaryname%$'\r'}
	curl -u ${USERID}:${PASSWORD} -X GET "$ART_URL/api/storage/$REPO/$binaryname" >> ${WORKSPACE}/MVN_CURL_OUT.log
	EXIT_STATUS=$?
	if [[ ${EXIT_STATUS} == 0 ]]
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
			if [[ -f $DEP_POM_FILE ]]
            then  
				binaryname=${binaryname%$'\r'}
				curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/list/$REPO/$DEP_POM_FILE" -T $DEP_POM_FILE
			else
				echo "$DEP_POM_FILE not found"
            fi
			echo "Tagging the appcode $APP_CODE for new artifact $binaryname"
			binaryname=${binaryname%$'\r'}
			curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=${APP_CODE};Matchtype=${Matchtype};BDScanStatus=${BDScanStatus}"
		elif [[ ${EXPR_URI_VAL} == 0 && ${EXPR_DOWNLOAD_URI} == 0 ]]
		then
			echo "$binaryname is already existing tagging the appcode"
			if [[ -f ${WORKSPACE}/Appcodedetails.txt ]] ; then 
				rm -rf ${WORKSPACE}/Appcodedetails.txt
			fi
            binaryname=${binaryname%$'\r'}
			curl -X GET -g -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode" > ${WORKSPACE}/Appcodedetails.txt
			AppCodevalue=`cat ${WORKSPACE}/Appcodedetails.txt | grep '"AppCode"' | awk -F ':' '{print $2}' |tr -d , | sed 's/[][]//g' | tr -d '\"'|sed 's/^ *//'|sed  's/ /,/g'|sed 's/,$//'`
			echo $AppCodevalue
       
			if [[ -z "$AppCodevalue" ]]
			then
                binaryname=${binaryname%$'\r'}
				curl -X PUT -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=${APP_CODE};Matchtype=${Matchtype};BDScanStatus=${BDScanStatus}"
				echo "Adding APP code for the first time to the  Property updated"
			else
				#echo "Version Already distributed to Env $AppCodevalue "
				IFS=',' read -r -a array <<< "$AppCodevalue"
				for index in "${!array[@]}"
				do
					if [[ ${array[index]} = ${APP_CODE} ]];
					then
					echo " Package has been already associated with Appcode . Please check"
					else
					echo "Adding AppCode property to the existing one "
					Appvalue="$APP_CODE,$AppCodevalue"
                    binaryname=${binaryname%$'\r'}
					curl -X PUT -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=$Appvalue;Matchtype=${Matchtype};BDScanStatus=${BDScanStatus}"
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
	done < $BinaryPath/NspcApprovedBinaryList.txt
	echo "==========================[START]Email Notification============================"
	cd $BinaryPath
	echo "Current working directory $PWD"
	rm -rf reports.zip
    zip reports.zip ApprovedBinaryList.txt BinaryList.txt UnMatchedBinaryList.txt UnApprovedBinaryList.txt $APP_CODE_*report.log
    if [ -f ./reports.zip ]
	then
    	echo "reports.zip is found"
		echo "Please find the BlackDuck scan reports attachement for the component $GIT_REPO" | mailx -a ./reports.zip -r group@company.com -s "Please Find the Reports for the $APP_CODE" user@company.com
	else
		echo "Unable to find reports.zip"
		exit 1
	fi
	echo "==========================[END]Email Notification============================"
	echo "===================[END]Uploading artifact and adding/appending AppCode==============================================="
	
	echo "=======================[Start]Cleaning git sources from workspace========================================"
    rm -rf ${WORKSPACE}/local_sub_repo
	echo "========================[END]Cleaning git sources from workspace==============================================="
elif [[ $PromoteType == Install_Copy_Manual_ApprovedBinList ]]
then
	echo "====================[START]Validation of parameters======================"
	if [[ ! -z $APP_CODE && ! -z $GIT_REPO ]]
	then
    	echo "App_Code: $APP_CODE"
		echo "App_Code: $GIT_REPO"
	else
		echo "These fields cannot be empty $APP_CODE/GIT_REPO"
		exit 1
	fi
	echo "====================[END]Validation of parameters======================"
	
	echo "==========================[START]Installation of Maven Binaries===================="
	if [ ! -d /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO} ]
		then
			mkdir -p /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}
		else
			echo "${APP_CODE}/${GIT_REPO} already exist under latest folder"
            rm -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}/*
	fi
	PropPoms=`echo ${FilePaths} | tr -d [:blank:]`
	IFS=',' read -r -a array <<< $PropPoms
	for index in "${!array[@]}"
	do
	FilePath=`echo ${array[index]}`
	FileFormat=`echo ${FilePath}|awk -F '/' '{print $NF}'|tr -d "[:blank:]"`
	if [[ ${FileFormat} == pom.xml ]]
	then
		cd ${WORKSPACE}/local_sub_repo
		DestPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}
		DestLibPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/${APP_CODE}/${GIT_REPO}/lib
		DestinationLibPath=`echo $DestLibPath`
		dirName=`dirname ${FilePath}`
		cd $dirName
		echo "dirName= $dirName"
		echo "DestPath  : $DestPath"
		echo "Copying settings.xml to current directory"
        if [ -f /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/settings.xml ]
		then
			echo "Copying Settings.xml to the ${DestPath}"
			cp -rf /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/settings.xml .
		else
			echo " Setting.xml is not available in latest path"
			exit 1
		fi
		echo "Installing Maven dependencies in $DestPath"
		mvn dependency:resolve -DskipTests -f pom.xml -gs ./settings.xml -Dm2.localRepository=${DestinationLibPath}
		if [[ $? != 0 ]]
		then
			echo "Failed to install dependencies, please check the pom.xml"
			exit 1
		fi
	elif [[ ${FileFormat} != pom.xml ]]
	then
		echo "Please give the correct pom.xml path including the pom.xml in FilePath value"
		exit 1
	else
		echo "Please give the correct value of ${FileFormat}"
		exit 1
	fi
	done
	echo "==========================[END]Installation of Maven Binaries===================="
	
	echo "==========================[START]Generation of BinaryList.txt===================="
	cd ${DestPath}
	if [ -f /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/whiltList.properties ]
	then
		cp /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/whiltList.properties .
		echo "Creating the BinaryList.txt file"
		${JAVA_HOME}/bin/java -jar /usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/separate-binary-type-1.0.jar ${DestinationLibPath}
		if [[ $? != 0 ]]
		then
			echo "Failed to Generate BinaryList.txt file"
			exit 1
		fi
	else
		echo "whiltList.properties not available in the latest folder"
		exit 1
	fi
    awk '{ sub("\r$", ""); print }' ${DestPath}/BinaryList.txt > InstalledBinaryList.txt
	echo "==========================[END]Generation of BinaryList.txt===================="
		
	echo "========================[START]Copying ApprovedBinaryList.txt==============================="
	export DestPath=/usr/local/web/arqe/AMA/AMAMonitor/jackson_AMA/latest/$APP_CODE/$GIT_REPO
    BinaryPath=`echo $DestPath`
	if [[ -d $BinaryPath && -d $BinaryPath/lib ]]
	then
		echo "Dependency folder's exists"
		cd $BinaryPath
		if [[ ! -f ${WORKSPACE}/ApprovedBinaryList.txt ]]
		then
			echo "Please the select ApprovedBinaryList.txt in the parameter"
			exit 1
		else
			ValidateBinFile=`echo ${WORKSPACE}/ApprovedBinaryList.txt | awk -F '/' '{print $NF}'`
			if [[ $ValidateBinFile == "ApprovedBinaryList.txt" ]]
			then
				if [[ -f $BinaryPath/ApprovedBinaryList.txt ]]
				then
					mv $BinaryPath/ApprovedBinaryList.txt $BinaryPath/ApprovedBinaryList_$(date +%F-%H_%M).txt
					if [ $? != 0 ]
					then
						echo "Unable to move old $BinaryPath/ApprovedBinaryList.txt"
						exit 1
					fi
				else
					echo "$BinaryPath/ApprovedBinaryList.txt is not available"
				fi
				if [[ -f $BinaryPath/NspcApprovedBinaryList.txt ]]
				then
					mv $BinaryPath/NspcApprovedBinaryList.txt $BinaryPath/NspcApprovedBinaryList_$(date +%F-%H_%M).txt
					if [ $? != 0 ]
					then
						echo "Unable to move old $BinaryPath/NspcApprovedBinaryList.txt"
						exit 1
					fi
				else
					echo "No $BinaryPath/NspcApprovedBinaryList.txt is not available"
				fi
				cp -rf ${WORKSPACE}/ApprovedBinaryList.txt $BinaryPath
				if [ $? != 0 ]
				then
					echo "Unable to copy ApprovedBinaryList.txt please check"
					exit 1
				fi
			else
				echo "please select the ApprovedBinaryList.txt from the parameter"
				exit 1
			fi
		fi
	else
		echo "echo unable to find the $BinaryPath or $BinaryPath/lib path please check"
		echo "Please install dependencies"
		exit 1
	fi
	if [[ -f $BinaryPath/ApprovedBinaryList.txt ]]
    then
		awk '{ sub("\r$", ""); print }' $BinaryPath/ApprovedBinaryList.txt > $BinaryPath/NspcApprovedBinaryList.txt
    else
    	echo "Unable to find $BinaryPath/ApprovedBinaryList.txt"
		exit 1
    fi
	echo "==============================[END]Copying ApprovedBinaryList.txt==============================="
	
	if [[ $Upload_Artifactory_Env == PROD ]]
	then
		ART_URL=http://prod.artifactory.com:8081/artifactory
		USERID=<username>
		PASSWORD=<password>
	elif [[ $Upload_Artifactory_Env == UAT ]]
	then
		ART_URL=http://uat.artifactory.com:8081/artifactory
		USERID=<username>
		PASSWORD=<password>
	else
		ART_URL=http://dev.artifactory.com:8081/artifactory
		USERID=<username>
		PASSWORD=<password>
	fi
	
	echo "===================[START]Uploading artifact and adding/appending AppCode==============================================="
	cd $BinaryPath/lib/
	while read binaryname
	do
		if [[ $binaryname == org/apache/maven/* ]]
		then
			REPO=$MAVEN_REPO
		elif [[ $binaryname == com/oracle/* || $binaryname == com/google/* || $binaryname == com/ibm/* ]]
		then
			REPO=$VENDOR_REPO
		elif [[ $binaryname == com/ssc/* || $binaryname == com/statestreet/* || $binaryname == com/statestr/* || $binaryname == com/stt/* ]]
		then
			REPO=$SSC_REPO
		else
			REPO=$OSS_REPO
		fi
	echo "$binaryname will be uploaded to $ART_URL/$REPO"
	rm -rf ${WORKSPACE}/MVN_CURL_OUT.log
	echo "Checkin the binary existance of $binaryname" 
	binaryname=${binaryname%$'\r'}
	curl -u ${USERID}:${PASSWORD} -X GET "$ART_URL/api/storage/$REPO/$binaryname" >> ${WORKSPACE}/MVN_CURL_OUT.log
	EXIT_STATUS=$?
	if [[ ${EXIT_STATUS} == 0 ]]
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
			if [[ -f $DEP_POM_FILE ]]
            then  
				binaryname=${binaryname%$'\r'}
				curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/list/$REPO/$DEP_POM_FILE" -T $DEP_POM_FILE
			else
				echo "$DEP_POM_FILE not found"
            fi
			echo "Tagging the appcode $APP_CODE for new artifact $binaryname"
			binaryname=${binaryname%$'\r'}
			curl -u ${USERID}:${PASSWORD} -X PUT "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=${APP_CODE};Matchtype=${Matchtype};BDScanStatus=${BDScanStatus}"
		elif [[ ${EXPR_URI_VAL} == 0 && ${EXPR_DOWNLOAD_URI} == 0 ]]
		then
			echo "$binaryname is already existing tagging the appcode"
			if [[ -f ${WORKSPACE}/Appcodedetails.txt ]] ; then 
				rm -rf ${WORKSPACE}/Appcodedetails.txt
			fi
            binaryname=${binaryname%$'\r'}
			curl -X GET -g -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode" > ${WORKSPACE}/Appcodedetails.txt
			AppCodevalue=`cat ${WORKSPACE}/Appcodedetails.txt | grep '"AppCode"' | awk -F ':' '{print $2}' |tr -d , | sed 's/[][]//g' | tr -d '\"'|sed 's/^ *//'|sed  's/ /,/g'|sed 's/,$//'`
			echo $AppCodevalue
       
			if [[ -z "$AppCodevalue" ]]
			then
                binaryname=${binaryname%$'\r'}
				curl -X PUT -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=${APP_CODE};Matchtype=${Matchtype};BDScanStatus=${BDScanStatus}"
				echo "Adding APP code for the first time to the  Property updated"
			else
				#echo "Version Already distributed to Env $AppCodevalue "
				IFS=',' read -r -a array <<< "$AppCodevalue"
				for index in "${!array[@]}"
				do
					if [[ ${array[index]} = ${APP_CODE} ]];
					then
					echo " Package has been already associated with Appcode . Please check"
					else
					echo "Adding AppCode property to the existing one "
					Appvalue="$APP_CODE,$AppCodevalue"
                    binaryname=${binaryname%$'\r'}
					curl -X PUT -u ${USERID}:${PASSWORD} "$ART_URL/api/storage/$REPO/$binaryname?properties=AppCode=$Appvalue;Matchtype=${Matchtype};BDScanStatus=${BDScanStatus}"
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
	done < $BinaryPath/NspcApprovedBinaryList.txt
	echo "===================[END]Uploading artifact and adding/appending AppCode==============================================="
	echo "=======================[Start]Cleaning ApprovedBinaryList.txt & git sources from workspace========================================"
    rm -rf ${WORKSPACE}/ApprovedBinaryList.txt
	rm -rf ${WORKSPACE}/local_sub_repo
	echo "========================[END]Cleaning ApprovedBinaryList.txt & git sources from workspace===============================================" 
else
	echo "Implement some other process"
    exit 1
fi
