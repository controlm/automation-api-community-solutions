#!/bin/bash
TIME=`date +%b-%d-%y`                      # This Command will read the date.
FILENAME=backup-nodedata-$TIME.tar.gz      # The filename including the date.
SRCDIR=/data/transaction/                  # Source backup folder.
DESDIR=/backup/transaction/                # Destination of backup file.
tar -zcPf $DESDIR/$FILENAME $SRCDIR