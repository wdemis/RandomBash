#!/usr/local/bin/bash

#############################################################################################################################################
# Project			:	BASH																												#
# Description		:	Shell script for issuing GET API call to BitBucket in order to retrieve all pull requests that the api user			#
#							is able to see. BitBucket doesn't allow users to pull data that they don't own, so this script isn't an 		#
#							end-all, be-all. However, across teams, it should be very accurate because most- if not all- teams have 		#
#							all dev members setup to be default reviewers. Therefore if one teammember creates a PR, then any member 		#
#							of the team should have been able to see it. Therefore reporting should be accurate.							#
#																																			#
# Input Params		:	BitBucket User Name - Required - the name of the teammember to search for as PR author								#
#																																			#
# Usage				:	./pullRequestHistory.sh WDemis																						#
#						This script uses curl to connect to BitBucket and expects a .netrc file to exist in /user/home						#
#																																			#
# Created by		:	Willy Demis																								#
# Created date		:	2023-05-19																											#
# Version			:	1.0																													#
#############################################################################################################################################

function timestamp()
{
	echo `date +"%Y-%m-%d %H:%M:%S"`
}

username=$1
prUrl='https://bitbucket.mydomain.com/rest/api/1.0/dashboard/pull-requests?state=MERGED'


echo ""
echo "***********************************************************************************************************"
echo "** Getting PRs from BitBucket where user: ${username} was author"
echo "***********************************************************************************************************"
starttime=`date '+%Y-%m-%d %H:%M:%S'`

outputFile=${username}_prs.csv
[ -e $outputFile ] && rm $outputFile

page="&start="
fetchPage="0"
lc_username="${username,,}"

while :
do

	prUrlPaged=${prUrl}${page}${fetchPage}
	echo -ne "\tQuerying BitBucket for metrics..."
	jsonMetrics=$(curl -s -n $prUrlPaged)
	echo " Done"

	echo -ne "\tParsing paged result set..."
	isLastPage=$(echo "$jsonMetrics" | jq '.isLastPage')
	fetchPage=$(echo "$jsonMetrics" | jq '.nextPageStart')
	metrics=$(echo "$jsonMetrics" | jq '.values[].closedDate |= (. / 1000 | strftime("%Y-%m-%d"))' | jq -r --arg author $lc_username '.values[] | select(.author.user.name | ascii_downcase | contains($author)) | {closedDate: (.closedDate), project: (.fromRef.repository.project.name), repo: (.fromRef.repository.name), author: (.author.user.displayName), reviewers:[(.reviewers[] | (.user.displayName))]}' | jq -s . | jq -r '.[] | [.closedDate, .project, .repo, .author, (.reviewers | join(":"))] | @csv')
	echo " Done"
	
	while IFS= read -r line; do
		if [[ ! -z "$line" ]]; then
			echo "$line" >> $outputFile
			echo -e "\t\t$line"
		fi
	done <<< "$metrics"

	isMore="false"
	if [ "$isLastPage" == "false" ]; then
		isMore="true"
	else
		echo -e "\tMore data available: $isMore"
		break
	fi

	echo -e "\tMore data available: $isMore"

done

endtime=`date '+%Y-%m-%d %H:%M:%S'`
start_seconds=$(date -j -f '%Y-%m-%d %H:%M:%S' "$starttime" '+%s')
end_seconds=$(date -j -f '%Y-%m-%d %H:%M:%S' "$endtime" '+%s')
duration=$(($end_seconds - $start_seconds))


echo "***********************************************************************************************************"
echo "** Metric analysis complete"
printf '**\t%-16s%s\n' 'Job status:' "SUCCESS"
printf '**\t%-16s%s\n' 'Job started at:' "$starttime"
printf '**\t%-16s%s\n' 'Job ended at:' "$endtime"
printf '**\t%-16s%s\n' 'Job duration:' "$duration seconds"
echo "***********************************************************************************************************"
echo ""


############################################################################################################################################
#                                                                                                                                          #
#                       END OF SCRIPT                                                                                                      #
#                                                                                                                                          #
#                                                                                                                                          #
############################################################################################################################################
