#!/usr/bin/env bash

set -u

verb="${1}"
user_id="${2}"
last_dl_date=$(cat "${user_id}/date.txt")
last_dl_date_epoch=$(date --date="${last_dl_date}" "+%s")

mkdir "${user_id}"
wget "https://fontstruct.com/fontstructors/${user_id}?order=by-recent-changes" --output-document="${user_id}/page-1.htm" --verbose

page_last=$(grep "fs-pagination__last" "${user_id}/page-1.htm" --context=1 | grep -P "(?<=page=)[0-9]+" --only-matching)

for page_i in $(seq 2 "${page_last?:}")
do
	wget "https://fontstruct.com/fontstructors/${user_id}?order=by-recent-changes&page=${page_i}" --output-document="${user_id}/page-${page_i}.htm"
done

all_caught_up=""

for file in "${user_id}/page-"*".htm"
do
	#for fstion_render_url in $(grep -E "[^\"]+renderer[^\"]+" "${file}" --only-matching)
	grep -P "renderer" "${file}" --after-context=3 --group-separator=$'\035' | while read -r -d $'\035' fstion_datax
	do
		fstion_render_url=$(echo "${fstion_datax}" | grep -E "[^\"]+renderer[^\"]+" --only-matching)
		fstion_slug=$(echo "${fstion_datax}" | grep -P "[^/]+(?=#comments)" --only-matching)
		fstion_modified=$(echo "${fstion_datax}" | grep -P "(?<=Last edited: <b>)([^<>]+)" --only-matching | sed -E "s/st|nd|rd|th|,//g")
		fstion_modified_n=$(date --date="${fstion_modified}" "+%F")
		fstion_modified_epoch=$(date --date="${fstion_modified}" "+%s")

		fstion_id=$(echo "${fstion_render_url}" | grep -P "(?<=id=)[0-9]+" --only-matching)
		fstion_v=$(echo "${fstion_render_url}" | grep -P "(?<=v=)[0-9a-z]+" --only-matching) # what is this anyway?
		fstion_folder="${user_id}/${fstion_id} ${fstion_slug}"
		fstion_out_file="${fstion_folder}/${fstion_modified_n}.json"

		# the fontstruction was renamed.
		# find the existing folder
		fstion_folder_existing=$(find -wholename "./${user_id}/${fstion_id} *" -type d)
		if [ "./${fstion_folder}" != "${fstion_folder_existing}" ]
		then
			mv "${fstion_folder}" "${fstion_folder_existing}" --verbose --no-clobber
		fi

		case "${verb}" in
			"init")
				mkdir "${fstion_folder}"
				wget "https://fontstruct.com/api/1/fontstructions/${fstion_id}?fast=1&v=${fstion_v}&_cacheable_fragment=1" --output-document="${fstion_out_file}"
				;;
			"update")
				if [ "${fstion_modified_epoch}" -ge "${last_dl_date_epoch}" ]
				then
					wget "https://fontstruct.com/api/1/fontstructions/${fstion_id}?fast=1&v=${fstion_v}&_cacheable_fragment=1" --output-document="${fstion_out_file}"
				else
					all_caught_up="true"
					break
				fi
				;;
		esac

		#fstion_slug=$(jq ".slug" "${fstion_out_file}" -r)
		fstion_modified_seconds_n=$(jq ".modified" "${fstion_out_file}" -r | sed "s/://g")
		fstion_out_file_new="${fstion_folder}/${fstion_modified_seconds_n}.json"

		mv "${fstion_out_file}" "${fstion_out_file_new}" --verbose --no-clobber

		if [ "${all_caught_up}" == "true" ]
		then
			break
		fi
	done
done

TZ="Europe/Berlin" LANG=C date "+%-d %B %Y" > "${user_id}/date.txt"
