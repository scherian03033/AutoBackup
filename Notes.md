#Design Concept
## Operational Process
	prepBackupDirs.sh - reads AutoBackup.cfg and creates a target directory structure to hold all the backups.
	doBackup.sh
		find all tar files in target directory
		looping over all lines in AutoBackup.cfg
			walk the tar file list to find the latest date for each level of backup
			find the corresponding file size
			Calculate the appropriate backup level based on file sizes
			Do a purge for this level
			incBackup.sh src tgt level
				figure out appropriate SNAR level
				copy snar file to new snar file for backup level if necessary
				mpTarHelper.sh

### SNAR file use
Each backup level gets its own copy of the snar file so an L1 is inclusive of the L0 changes to date and an L2 is inclusive of the L1 changes to date. Thus, if an L0 snar is overwritten, the prior L1 backup is still accessible using the L1 snar file.

Once things wrap back to L0, we must save a copy of the original L0 snar file away by date, and similarly for L1 and L2 as the backup level increases. The key thing to note is that *the date on the snar file tells you which tar files apply to it, i.e. those with a date **older** than that on the snar.*

## Target Filesystem
* AutoBackup
	* Target Directory
		* Source Directory Name
			* any snar files
			* L0
				* tar files
			* L1
				* tar files
			* L2
				* tar files

**Question:** How can we correlate individual tar and snar files to identify the set to which they belong? Since the same L0 can be part of multiple L0..L2 combinations, putting a set id in the tar file name may not be prudent. **Answer:** Use date.

## Frequency of Backups
* L0 backups at least yearly
* L1 backups at least monthly
* L2 backups weekly

## Retention Policy

### Local Storage
Keep local backups until they trigger the purge policy.

### Offsite Glacier Storage
	When backup is complete
		compare the most recent backup set to what's on Glacier
		If it's completely new
			Upload it
		Delete any backup set that's older than 3 months

## Purging Policy
* purge L0 backups after 1 year
* purge L1 backups after 3 months or if corresponding L0 is being purged
* purge L2 backups after 1 month or if corresponding L0 or L1 are being purged

## Restoring Backups
from the restore location:

	tar -M xvf ${TGT_DIR}/${SRC_DIR}/${LVL}/mypics.1.tar -g ${SNAR_FILE} -F ${SCRIPT_DIR}/mpTarHelper.sh
The SNAR_FILE can be /dev/null since the tar chunk knows what to do.
-M or --multi-volume tells tar multiple files exist.
# Testing
## Test Conditions
### prepBackupDirs.sh
1. Non-existent target directory
2. Already existing target subdirectory

### doBackup.sh
1. Backup of a single source directory - automatic
	* First in cfg file
	* Last in cfg file
2. Detect that no backup is required
3. Backup of a single source directory - specified level
	* L0
		* when L0 doesn't exist
		* when L0 already exists
	* L1
		* when L0 doesn't exist
		* when L0 exists and L1 doesn't exist
		* when L0 exists and L1 exists
	* L2
		* when L1 doesn't exist
		* when L1 exists and L2 doesn't exist
		* when L1 exists and L2 exists
4. Backup of a single source directory - auto
	* when no backup exists
	* when L0 exists
	* when L0 and L1 exist
		* and L1 is the correct next level
		* and L2 is the correct next level
	* when L0, L1 and L2 exist
		* and L0 is the correct next level
		* and L1 is the correct next level
		* and L2 is the correct next level
5. Backup of all source directories - auto (variants should be covered by above)
6. Purge of old files

### incRestore.sh
1. when most recent backup is an L0
2. when most recent backup is an L1
	* and older L1 exists
	* and older L1 and L2 exist
	* and corresponding L0 is missing 
3. when most recent backup is an L2
	* and older L1 exists but older L0 is missing
	* and older L1 is missing but older L0 exists
	* and older L1 is missing and older L0 is missing
	* older L1 and L0 exist

# E2E Test Run
###prepBackupDirs.sh
1. Run with no AutoBackup target dir - created it. P
2. Run with stuff already in target directories - deleted stuff. P

###doBackup.sh
1. Auto backup of single source
	* first source in cfg file L0, L1, L2, L0 - P
	* last source in cfg file L0, L1, L2, L0 - P
2. Auto backup of last source - no file change, no backup - P
3. Backup of NetSanjay
	* L0
		* when L0 doesn't exist - P: created L0 backup, log
		* when L0 already exists - P: saved snar, new backup, saved log
	* L1
		* when L0 snar doesn't exist - P: declared error, saved log
		* when L0 snar exists, tar no - F: created incremental w/o base
		* when L0 exists and L1 doesn't exist - P: created L1, log
		* when L0 exists and L1 exists - P: saved snar, new L1, saved log
	* L2
		* when L1 doesn't exist
		* when L1 exists and L2 doesn't exist
		* when L1 exists and L2 exists

## Test Status
1. Test creation of L0, L1, L2 backup sets.
2. Test wrap back to L0 and correct saving away of snar files.
3. Test restore of backups from current tar/snar set.
4. Test restore of backups from <date>-saved tar/snar set.
5. Test purge removes correct files.

## Interesting Defects
### D1: Snar overwrite
#### Problem:
currently snar files are getting overwritten so only the most recent backup is recoverable. Is this okay? It means for any given source directory, there is only one recoverable L0, L1 and L2 backup set.

What would I like to have happened?
On Glacier, there should be one complete backup, either L0, L0..L1 or L0..L2.
Locally, there should be some number of backup sets, purged by age policy. For now, it's okay to have only one backup set.

####Solution
a. add a snar set ID to the filename.
b. when deleting a snar file, move it to a date-keyed name instead. Will need some care around handling L1 and L2 snar files - done
c. when creating a new backup, purge all backups for that target and level that are older than the purge period for that level. Given the decreasing retention period as level goes up, no higher level backup should ever exist when its lower level dependency has been purged.

It turned out this was not a bug at all. The snar file is not required when restoring tar files. You just have to restore the files in the right order.
### D2: NAS Scheduler doesn't run scripts
####Problem####
Synology scripts were not running from the scheduler but ran fine from command line.
####Solution####
There is almost no PATH loaded when scripts are run from the scheduler. This means you have to provide absolute paths for everything, including other scripts sourced from the running script and utilities. Synology also couldn't handle "date -v" so find was used for purging.  

#TO DO
* Thorough system test
* Fix case of snar present, dependent tar missing, still does incremental

## DONE
* Dynamically check OS and set up tar, chunk, paste using uname -a.
	* especially absolute path name issues - done
* Synology notifications - done
	* http://forum.synology.com/enu/viewtopic.php?f=39&t=63520
* OS X notification:	osascript -e 'display notification "Lorem ipsum dolor sit amet" with title "Title"' - done
* Fix purge for date -v problem - done
* Change purge so that it doesn't purge the only L0 or L1 available.
* bc not available on Synology. Replace with perl.
* Unify path name model.
	* check platform at beginning of doBackup.sh and use it to set the SCRIPTDIR. Use scriptdir for everything else.
* Path names end up being absolute from root. Make them relative from SRCDIR
* check last modification date before deciding to do a backup using find -newer <reference_file>
* save copy of log file before overwriting it
* make purge handle old Autobackup.log files
* fix getBkupSize function for Linux - no paste, replace with perl
* Make sure "no file change" takes precedence over new backup level needed
* Thorough code walkthrough / unit test