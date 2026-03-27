#!/bin/bash
read -r -p "FileName: " FileName
docker exec -e "FileName=$FileName" EDCB /bin/bash /var/local/edcb/RecEnd.sh

