/*
 * file: dramChecker.c
 *
 * This C program decodes the eSeries dram eccStatus number, from the
 * "pccl_ping.exe  -core <dumpFileName>.udmp -debug lm11.debug -hw
lm10 -mem 1024" dos command
 * output, into double bit ECC error, single bit ECC error, both single and
double bit ECC errors,
 * or neither single nor double bit ECC errors.
 * (from email from From: Puneet Joshi Sent: Monday, December 21, 2009 12:30 PM)
 *
 * Written by Jonathan Natale for Juniper Networks on 20-Nov-2010.
 *
 * ver hist
 * 0 - init
 *
 */

#include <stdio.h>
#include <ctype.h>
#include <string.h>

int main(int argc, char **argv) {
    char             *flags;
    char              hexChar[3];
    unsigned long int hexCharNum;
    unsigned long int i,j;
    unsigned long int flagsNum;
    int len;

    if((argc != 2) || ((argc != 2) && strcmp(argv[1],"?")))  {
        printf("Usage: <flags (in hex w/o 0x)>\n");
        printf("    Decodes the eSeries dram eccStatus number, from the\n");
        printf("    \"print__11Ic1Detector\" shell command\n");
        printf("    output, into double bit ECC error, single bit ECC error, both single and double bit ECC errors,\n");
        printf("    or neither single nor double bit ECC errors.\n");
        printf("    Written by Jonathan Natale for Juniper Networks on 20-Nov-2010.\n");
        return(1);
    }
    flags = argv[1];
    len = strlen(flags);

/*
 *  Sanity checks:
 */
    for(i=0;i<len;i++) {
        if(!isxdigit(flags[i])) {
            printf("Sorry, %s are not a valid flags.\n", flags);
            printf("       ");
            for(j=0;j<i;j++) {
                printf(" ");
            }
            printf("^\n");
            printf("Please try again.  Exiting ...\n");
            return(3);
        }
    }

    flagsNum=0;
    hexChar[1] = '\0';
    for(i=0;i<len;i++) {
        flagsNum = flagsNum << 4;
        hexChar[0] = flags[i];
        hexCharNum=strtol(hexChar, (char **)NULL, 16);
        flagsNum = flagsNum | hexCharNum;
    }

   
if((((flagsNum>>9)&1)|((flagsNum>>25)&1))&&(((flagsNum>>8)&1)|((flagsNum>>24)&1))) {
        printf("both single and double bit ECC errors\n");
    } else if(((flagsNum>>8)&1)|((flagsNum>>24)&1)) {
        printf("only single bit ECC errors\n");
    } else if(((flagsNum>>9)&1)|((flagsNum>>25)&1)) {
        printf("only double bit ECC errors\n");
    } else {
        printf("neither single nor double bit ECC errors\n");
    }

    return(0);
}

