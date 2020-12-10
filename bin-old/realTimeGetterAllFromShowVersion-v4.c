/*  File: realTimeGetterAllFromShowVersion-v4.c
*
*
*
* This C program takes as INPUT(in a file) the output from an eSeries "show version" CLI command, for example:
*
* Juniper Edge Routing Switch ERX-1400
* Copyright (c) 1999-2008 Juniper Networks, Inc.  All rights reserved.
* System Release: 8-2-3p0-5-1.rel
*         Version: 8.2.3 patch-0.5.1 [BuildId 10739]   (March 24, 2009  10:50)
* System running for: 553 days, 16 hours, 13 minutes, 20 seconds
*         (since TUE SEP 01 2009 05:21:30 UTC)
*
 * slot  state        type        admin  spare running release   slot uptime 
 * ---- ------- ---------------- ------- ----- --------------- ---------------
* 0    standby OC3/OC12/DS3-ATM enabled spare 8-2-3p0-5-1.rel       ---     
 * 1    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:15s
* 2    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:14s
* 3      ---         ---          ---    ---        ---             ---     
 * 4    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:12s
* 5    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:10s
* 6    online  SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel 553d16h:10m:27s
* 7    standby SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel       ---     
 * 8      ---         ---          ---    ---        ---             ---     
 * 9    online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:33s
* 10     ---         ---          ---    ---        ---             ---     
 * 11     ---         ---          ---    ---        ---             ---      
 * 12   online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:36s
* 13     ---         ---          ---    ---        ---             ---     
 *
* --and provides as OUTPUT(to the monitor) the time that this eSeries "show version" CLI command was executed;
* ALSO, it converts the slot uptimes to the actual times the slots came up, in this example it would be:
* Juniper Edge Routing Switch ERX-1400
* Copyright (c) 1999-2008 Juniper Networks, Inc.  All rights reserved.
* System Release: 8-2-3p0-5-1.rel
*         Version: 8.2.3 patch-0.5.1 [BuildId 10739]   (March 24, 2009  10:50)
* System running for: 553 days, 16 hours, 13 minutes, 20 seconds
*         (since TUE SEP 01 2009 05:21:30 UTC)
* Time this "show version" CLI command was executed:                                Tue Mar  8 21:34:50 2011
*
* slot  state        type        admin  spare running release   slot uptime
* ---- ------- ---------------- ------- ----- --------------- ---------------
* 0    standby OC3/OC12/DS3-ATM enabled spare 8-2-3p0-5-1.rel       ---
* 1    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:15s since Tue Sep  1 05:33:35 2009
* 2    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:14s since Tue Sep  1 05:33:36 2009
* 3      ---         ---          ---    ---        ---             ---
* 4    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:12s since Tue Sep  1 05:33:38 2009
* 5    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:10s since Tue Sep  1 05:33:40 2009
* 6    online  SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel 553d16h:10m:27s since Tue Sep  1 05:24:23 2009
* 7    standby SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel       ---
* 8      ---         ---          ---    ---        ---             ---
* 9    online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:33s since Tue Sep  1 05:32:17 2009
* 10     ---         ---          ---    ---        ---             ---
* 11     ---         ---          ---    ---        ---             ---
* 12   online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:36s since Tue Sep  1 05:32:14 2009
*
*
* Caveats:
* 0 - input format must be exact
* 1 - output is in local time, ASSUMED to be UTC (at least, that is what I like)
* 2 - the eSeries may add trailing spaces, which breaks this code.  An example workaround is:
*         cat inputFile | sed 's/ *$//' > inputFileCleaned
*
* Written by Jonathan Natale for Juniper Networks on 11-Mar-2011.
*
* Version History:
* 0 - works
* 1 - handles trailing spaces
* 2 - fixed over-write bug:
* since Wed May  4 07:42:01 2011pare e320_9-0-1p0-7-5-2.rel 0d00h:12m:18s
* 3 - now handles trailing spaces
* 4 - nixed leading 0x01 chars on lines after first slot timestamp by adding "line[j] = '\0'" on line 508
*     and removed a lot of commented out debug code
*
* To Do:
* 0 - get into this format: TUE MAR 08 2011 21:34:50 UTC
*/
#include <stdio.h>
#include <time.h>
#include <unistd.h>
#define MAX_STRING_SIZE 512
int main(int argc, char **argv) {
    FILE  *inputFile_ptr;
    int    i,j,k;
    time_t t;
    struct tm time_str;
    char  *line;
    char   lineBuf[MAX_STRING_SIZE];
    long int currentTimeInSecondsSinceEpoch = 1234567890;
    long int slotBootTimeInSecondsSinceEpoch = 313131313;
    int daysDiffInt = 0;
    int hoursDiffInt = 0;
    int minutesDiffInt = 0;
    int secondsDiffInt = 0;
    char daysDiffString[6];
    char hoursDiffString[3];
    char minutesDiffString[3];
    char secondsDiffString[3];
    // command line validate, and online help
    if(argc != 2) {
        printf("\n");
        printf("\n");
        printf("    Usage: %s <input text file 1>\n", argv[0]);
        printf("\n");
        printf("This C program takes as INPUT(in a file) the output from an eSeries \"show version\" CLI command, for example:\n");
        printf("\n");
        printf("Juniper Edge Routing Switch ERX-1400\n");
        printf("Copyright (c) 1999-2008 Juniper Networks, Inc.  All rights reserved.\n");
        printf("System Release: 8-2-3p0-5-1.rel\n");
        printf("        Version: 8.2.3 patch-0.5.1 [BuildId 10739]   (March 24, 2009  10:50)\n");
        printf("System running for: 553 days, 16 hours, 13 minutes, 20 seconds\n");
        printf("        (since TUE SEP 01 2009 05:21:30 UTC)\n");
        printf("\n");
        printf("slot  state        type        admin  spare running release   slot uptime  \n");
        printf("---- ------- ---------------- ------- ----- --------------- ---------------\n");
        printf("0    standby OC3/OC12/DS3-ATM enabled spare 8-2-3p0-5-1.rel       ---      \n");
        printf("1    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:15s\n");
        printf("2    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:14s\n");
        printf("3      ---         ---          ---    ---        ---             ---      \n");
        printf("4    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:12s\n");
        printf("5    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:10s\n");
        printf("6    online  SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel 553d16h:10m:27s\n");
        printf("7    standby SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel       ---      \n");
        printf("8      ---         ---          ---    ---        ---             ---      \n");
        printf("9    online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:33s\n");
        printf("10     ---         ---          ---    ---        ---             ---      \n");
        printf("11     ---         ---          ---    ---        ---             ---      \n");
        printf("12   online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:36s\n");
        printf("13     ---         ---          ---    ---        ---             ---      \n");
        printf("\n");
        printf("\n");
        printf("--and provides as OUTPUT(to the monitor) the time that this eSeries \"show version\" CLI command was executed;\n");
        printf("ALSO, it converts the slot uptimes to the actual times the slots came up, in this example it would be:\n");
        printf("\n");
        printf("Juniper Edge Routing Switch ERX-1400\n");
        printf("Copyright (c) 1999-2008 Juniper Networks, Inc.  All rights reserved.\n");
        printf("System Release: 8-2-3p0-5-1.rel\n");
        printf("        Version: 8.2.3 patch-0.5.1 [BuildId 10739]   (March 24, 2009  10:50)\n");
        printf("System running for: 553 days, 16 hours, 13 minutes, 20 seconds\n");
        printf("        (since TUE SEP 01 2009 05:21:30 UTC)\n");
        printf("Time this \"show version\" CLI command was executed:                          Tue Mar  8 21:34:50 2011\n");
        printf("\n");
        printf("slot  state        type        admin  spare running release   slot uptime  \n");
        printf("---- ------- ---------------- ------- ----- --------------- ---------------\n");
        printf("0    standby OC3/OC12/DS3-ATM enabled spare 8-2-3p0-5-1.rel       ---      \n");
        printf("1    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:15s Tue Sep  1 05:33:35 2009\n");
        printf("2    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:14s Tue Sep  1 05:33:36 2009\n");
        printf("3      ---         ---          ---    ---        ---             ---      \n");
        printf("4    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:12s Tue Sep  1 05:33:38 2009\n");
        printf("5    online  OC3-4A           enabled  ---  8-2-3p0-5-1.rel 553d16h:01m:10s Tue Sep  1 05:33:40 2009\n");
        printf("6    online  SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel 553d16h:10m:27s Tue Sep  1 05:24:23 2009\n");
        printf("7    standby SRP-10Ge         enabled  ---  8-2-3p0-5-1.rel       ---      \n");
        printf("8      ---         ---          ---    ---        ---             ---      \n");
        printf("9    online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:33s Tue Sep  1 05:32:17 2009\n");
        printf("10     ---         ---          ---    ---        ---             ---      \n");
        printf("11     ---         ---          ---    ---        ---             ---      \n");
        printf("12   online  GE               enabled  ---  8-2-3p0-5-1.rel 553d16h:02m:36s Tue Sep  1 05:32:14 2009\n");
        printf("13     ---         ---          ---    ---        ---             ---      \n");
        printf("\n");
        printf("\n");
        printf("Caveats:\n");
        printf("0 - input format must be exact\n");
        printf("1 - output is in local time, ASSUMED to be UTC (at least, that is what I like)\n");
        printf("2 - the eSeries may add trailing spaces, which breaks this code.  An example workaround is:\n");
        printf("        cat inputFile | sed 's/ *$//' > inputFileCleaned\n");
        printf("\n");
        printf("Written by Jonathan Natale for Juniper Networks on 11-Mar-2011.\n");
        printf("\n");
        return(1);
    }
    // open input file
    if((inputFile_ptr = fopen(argv[1], "r")) == NULL) {
        printf("Sorry, unable to open %s file.\n", argv[1]);
        printf("Please try again.  Exiting ...\n");
        return(2);
    }
    // read and echo preliminary lines that we don't care about, finally reading first line that we do care about
    while(1) {
        if((line = fgets(lineBuf, MAX_STRING_SIZE - 2, inputFile_ptr)) == NULL) {
        printf("Sorry, unexpected NULL line read in %s file.\n", inputFile_ptr);
        printf("Please try again.  Exiting ...\n");
            return(3);
        }
        if(strstr(line,  "System running for: ") == NULL) {
            printf("%s", line);
        } else {
            break;
        }
    }
    // echo first line that we care about
    printf("%s", line);
    // parse out time diff from first line, for example:
    // System running for: 553 days, 16 hours, 13 minutes, 20 seconds
    // 012345678901234567890123456789012345678901234567890123456789012
    //           1         2         3         4         5         6
    // init total char counter
    i = 0;
    // read number of days
    // init field char counter to count number of chars in leading text
    j = 0;
    // throw away chars in leading text
    while(!isdigit(line[i])) {
        i++;
        j++;
    }
    // flag error if too many chars in leading text
    if(j != 20) {
        printf("Sorry, wrong number of non-numeric characters before a number, in first line (got %d, expected 20).\n", j);
        printf("Please try again.  Exiting ...\n");
        return(4);
    }
    // init field char counter to count number of digits in number of days
    j = 0;
    // read the number of days
    while(isdigit(line[i])) {
        daysDiffString[j] = line[i];
        if(j >= 5) {
            printf("Sorry, wrong number of digits in the number of days, in first line (got %d, expected between 1 and 5).\n", j + 1);
            printf("Please try again.  Exiting ...\n");
            return(5);
        }
        i++;
        j++;
    }
    daysDiffString[j] = '\0';
    daysDiffInt = atoi(daysDiffString);
    //read number of hours
    // init field char counter to count number of chars in text between days and hours
    j = 0;
    // throw away chars in text between days and hours
    while(!isdigit(line[i])) {
        i++;
        j++;
    }
    // flag error if too many chars in leading text
    if((j != 6) && (j != 7)) {
        printf("Sorry, wrong number of characters after the number of days and before the number of hours, in first line (got %d, expected 6 or 7).\n", j);
        printf("Please try again.  Exiting ...\n");
        return(6);
    }
    // init field char counter to count number of digits in number of hours
    j = 0;
    // read the number of hours
    while(isdigit(line[i])) {
        hoursDiffString[j] = line[i];
        if(j >= 2) {
            printf("Sorry, wrong number of digits in the number of hours, in first line (got %d, expected between 1 and 2).\n", j + 1);
            printf("Please try again.  Exiting ...\n");
            return(7);
        }
        i++;
        j++;
    }
    hoursDiffString[j] = '\0';
    hoursDiffInt = atoi(hoursDiffString);
    //read number of minutes
    // init field char counter to count number of chars in text between hours and minutes
    j = 0;
    // throw away chars in text between hours and minutes
    while(!isdigit(line[i])) {
        i++;
        j++;
    }
    // flag error if too many chars in leading text
    if((j != 7) && (j != 8)) {
        printf("Sorry, wrong number of characters after the number of hours and before the number of minutes, in first line (got %d, expected 7 or 8).\n", j);
        printf("Please try again.  Exiting ...\n");
        return(8);
    }
    // init field char counter to count number of digits in number of minutes
    j = 0;
    // read the number of minutes
    while(isdigit(line[i])) {
        minutesDiffString[j] = line[i];
        if(j >= 2) {
            printf("Sorry, wrong number of digits in the number of minutes, in first line (got %d, expected between 1 and 2).\n", j + 1);
            printf("Please try again.  Exiting ...\n");
            return(9);
        }
        i++;
        j++;
    }
    minutesDiffString[j] = '\0';
    minutesDiffInt = atoi(minutesDiffString);
    //read number of seconds
    // init field char counter to count number of chars in text between minutes and seconds
    j = 0;
    // throw away chars in text between minutes and seconds
    while(!isdigit(line[i])) {
        i++;
        j++;
    }
    // flag error if too many chars in leading text
    if((j != 9) && (j != 10)) {
        printf("Sorry, wrong number of characters after the number of minutes and before the number of seconds, in first line (got %d, expected 9 or 10).\n", j);
        printf("Please try again.  Exiting ...\n");
        return(10);
    }
    // init field char counter to count number of digits in number of seconds
    j = 0;
    // read the number of seconds
    while(isdigit(line[i])) {
        secondsDiffString[j] = line[i];
        if(j >= 2) {
            printf("Sorry, wrong number of digits in the number of seconds, in first line (got %d, expected between 1 and 2).\n", j + 1);
            printf("Please try again.  Exiting ...\n");
            return(11);
        }
        i++;
        j++;
    }
    secondsDiffString[j] = '\0';
    secondsDiffInt = atoi(secondsDiffString);
    // read and echo second line that we care about
    if((line = fgets(lineBuf, MAX_STRING_SIZE - 2, inputFile_ptr)) == NULL) {
        return(12);
    }
    printf("%s", line);
    // parse second line, which is time router came up, for example:
    //    <startOfLine>         (since TUE SEP 01 2009 05:21:30 UTC)
    if(strptime(line, "         (since %a %b %d %Y %T UTC)", &time_str) == (int)NULL) {
        printf("strptime() failed!\n");
        return(13);
    }
    //the above fills in time_str struct
    // not set by strptime(); tells mktime() to determine
    // whether daylight saving time is in effect
    time_str.tm_isdst = -1;
    // get the number of seconds since epoch at the time the router came up
    t = mktime(&time_str);
    if(t == -1) {
        printf("mktime failed!");
        return(14);
    } else {
        // Get the current time (time the "show version" command was executed) based on the number of seconds since epoch at the time the router came up,
        // and the time the router has been up, and then...
        currentTimeInSecondsSinceEpoch = (long)t + secondsDiffInt + minutesDiffInt * 60 + hoursDiffInt * 3600 + daysDiffInt * 86400;
    }
    //...print this time in human readable format
    printf("Time this \"show version\" CLI command was executed:                                   %s", asctime(gmtime(&currentTimeInSecondsSinceEpoch)));
    // read and echo intermediary lines that we don't care about (no timestamp), finally reading next line that we do care about (has a timestamp)
    //while(line != EOF) { //do I even need this [w/ another fgets]???
    while(1) {
        while(1) {
            // this is where this program normally exits
            if((line = fgets(lineBuf, MAX_STRING_SIZE - 2, inputFile_ptr)) == NULL) {
                return(0);
            }
            // looking for "m:", from "1     online  LM-10   enabled  ---  e320_9-3-3p0-2-1.rel 5d17h:37m:50s" for example
            if(strstr(line,  "m:") == NULL) {
                // ???[minor] risk of crash for large lines???...
                printf("%s", line);
            } else {
                break;
            }
        }
        // searching backwards, find last <nonspace>
        for(k=strlen(line)-1;k>=-1;k--) {
            if(k==-1) {
            printf("Sorry, unexpectedly, a nonspace was not found in the input line: <%s>.\n", line);
            printf("Please try again.  Exiting ...\n");
                return(16);
            }
            if((line[k] != ' ') && (line[k] != '\n')) {
                //k = i + 1; // remember place where the line really ends
                break;
            }
        }
        // searching backwards, find last <space> (this is 1 less than where the uptime field starts)
        for(i=k;i>=-1;i--) {
            // if space is never found, something is wrong with the input (actually, it should be found WAY before this)
            if(i==-1) {
            printf("Sorry, unexpectedly, a space was not found in the input line: <%s>.\n", line);
            printf("Please try again.  Exiting ...\n");
                return(16);
            }
            // if <space> is found...
            if(line[i] == ' ') {
                j = i + 1; // remember place where the uptime field starts
                break;
            }
        }
        // assuming what remains in the line is something like this (hell, I can't error check the whole world!): 553d16h:01m:15s
        // get days
        i = 0;
        while(isdigit(line[j])) {
            daysDiffString[i++] = line[j++];
        }
        daysDiffString[i] = '\0';
        daysDiffInt = atoi(daysDiffString);
        while(!isdigit(line[j++])); // throw away non numeric chars (should only be one, "d")
        j--;
        // get hours
        i = 0;
        while(isdigit(line[j])) {
            hoursDiffString[i++] = line[j++];
        }
        hoursDiffString[i] = '\0';
        hoursDiffInt = atoi(hoursDiffString);
        while(!isdigit(line[j++])); // throw away non numeric chars (should only be two, "h:")
        j--;
        // get minutes
        i = 0;
        while(isdigit(line[j])) {
            minutesDiffString[i++] = line[j++];
        }
        minutesDiffString[i] = '\0';
        minutesDiffInt = atoi(minutesDiffString);
        while(!isdigit(line[j++])); // throw away non numeric chars (should only be two, "m:")
        j--;
        // get seconds
        i = 0;
        while(isdigit(line[j])) {
            secondsDiffString[i++] = line[j++];
        }
        secondsDiffString[i] = '\0';
        secondsDiffInt = atoi(secondsDiffString);
        while(!isdigit(line[j++])) {
            // throw away non numeric chars (should only be two, "m:")
        }
        j--;
        // calculate slot boot time
        slotBootTimeInSecondsSinceEpoch = currentTimeInSecondsSinceEpoch - secondsDiffInt - minutesDiffInt * 60 - hoursDiffInt * 3600 - daysDiffInt * 86400;
        // append the slot boot time to the line(including its '\n', but NOT including the '\n' from the line)
        j = strlen(line) - 1;
        // insert " since " delimiter (ya, I know this is hacky)
        // --in FACT, SOOO hacky it lead to this bug:
        //     since Wed May  4 07:42:01 2011pare e320_9-0-1p0-7-5-2.rel 0d00h:12m:18s
        line[j++] = ' ';
        line[j++] = 's';
        line[j++] = 'i';
        line[j++] = 'n';
        line[j++] = 'c';
        line[j++] = 'e';
        line[j++] = ' ';
        for(i=0;i<strlen(asctime(gmtime(&slotBootTimeInSecondsSinceEpoch)));i++) {
            line[j++] = asctime(gmtime(&slotBootTimeInSecondsSinceEpoch))[i];
        }
        line[j] = '\0';
        // echo line with uptime and with time that it booted appended
        printf("%s", line);
    }
    // this program should exit above at "this is where this program normally exits" above
    printf("Sorry, unexpected program exit point, something might be broken!\n");
    printf("Please try again and/or contact the program author, Jonathan Natale.  Exiting ...\n");
    return(0);
}
