/*
 * file: selCrChecker-v1.c
 *
 * This C program decodes one line from the eSeries "show version" CLI command output.
 * It determines if the LM-10 is a CR card or not, and if it is a SEL fixed card or not.
 * It also gets the sn and does some sanity checks.
 *
 * Example input:
 *     selCrChecker-v1.exe 0      LM-10     4307327561   4500009501     A05      1024       1.5
 *
 * Example output:
 *     sn4307327561 noCr noSelFix
 *
 * Explanation:
 *     For    CR cards (4500009501),  A12 or greater is a SEL fixed card.
 *     For nonCR cards (4500009504),  A02 or greater is a SEL fixed card.
 *         ^^^                   ^     ^
 * (refer to KA38052 and KA36085)
 *
 * Written by Jonathan Natale for Juniper Networks on 11-Feb-2011.
 *
 * Todo:
 *     Add short version switch -s that accepts "4500009501     A05", for example,
 *     and pulls only last 2 assy digits (is forgiving).
 *
 */
 
#include <stdio.h>
#include <ctype.h>
#include <string.h>
 
int main(int argc, char **argv) {
    int i;
    char sn[11];
    char assy[3];  // last 2 digits only
    char rev[3];    // without the leading "A"
 
    if((argc != 8) || ((argc != 8) && strcmp(argv[1],"?")))  {
        printf("Usage:\n");
        printf("    Decodes one line from the eSeries \"show version\" CLI command output.\n");
        printf("    Determines if the LM-10 is a CR card or not, and if it is a SEL fixed card or not.\n");
        printf("    Also gets the sn and does some sanity checks.\n");
        printf("    Example input:\n");
        printf("        selCrChecker-v1.exe 0      LM-10     4307327561   4500009501     A05      1024       1.5\n");
        printf("    Example output:\n");
        printf("        sn4307327561 noCr noSelFix\n");
        printf("    Explanation:\n");
        printf("        For    CR cards (4500009501),  A12 or greater is a SEL fixed card.\n");
        printf("        For nonCR cards (4500009504),  A02 or greater is a SEL fixed card.\n");
        printf("            ^^^                   ^     ^\n");
        printf("    (refer to KA38052 and KA36085)\n");
        printf("    Written by Jonathan Natale for Juniper Networks on 11-Feb-2011.\n");
        return(1);
    }
 
/*
 *  Sanity checks:
 */
 
    // input(s) too long?
    for(i=1;i<=7;i++) {
        if(strlen(argv[i]) > 10) {
            printf("Sorry, %s is too long (should be less then 11 chars).\n", argv[i]);
            printf("Please try again.  Exiting ...\n");
            return(2);
        }
    }
 
    // slot #
    if(strlen(argv[1]) > 2) {
        printf("Sorry, %s is too long (should be less then 3 chars).\n", argv[1]);
        printf("Please try again.  Exiting ...\n");
        return(3);
    }
    if(atoi(argv[1]) > 16 || atoi(argv[1]) < 0) {
        printf("Sorry, %s is out of range (should be between 0 and 16, inclusive).\n", argv[1]);
        printf("Please try again.  Exiting ...\n");
        return(4);
    }
 
    // card type
    if(strcmp(argv[2], "LM-10")) {
        printf("Sorry, %s is wrong type (should be \"LM-10\").\n", argv[2]);
        printf("Please try again.  Exiting ...\n");
        return(5);
    }
 
    // sn
    if(strlen(argv[3]) != 10) {
        printf("Sorry, %s is the wrong number of digits (should be 10).\n", argv[3]);
        printf("Please try again.  Exiting ...\n");
        return(6);
    }
    for(i=0;i<10;i++) {
        if(!isdigit(argv[3][i])) {
            printf("Sorry, %s is invalid (should be decimal).\n", argv[3]);
            printf("Please try again.  Exiting ...\n");
            return(7);
        }
    }
 
    // assy
    if(strcmp(argv[4], "4500009501") && strcmp(argv[4], "4500009504")) {
        printf("Sorry, %s is invalid (should either \"4500009501\" or \"4500009504\").\n", argv[4]);
        printf("Please try again.  Exiting ...\n");
        return(8);
    }
 
    // rev
    if(strlen(argv[5]) != 3) {
        printf("Sorry, %s is the wrong number of digits (should be 3).\n", argv[5]);
        printf("Please try again.  Exiting ...\n");
        return(9);
    }
    if(argv[5][0] != 'A') {
        printf("Sorry, %s is wrong (should start with an A).\n", argv[5]);
        printf("Please try again.  Exiting ...\n");
        return(10);
    }
    for(i=1;i<3;i++) {
        if(!isdigit(argv[5][i])) {
            printf("Sorry, %s is invalid (should have 2 trailing decimal digits).\n", argv[5]);
            printf("Please try again.  Exiting ...\n");
            return(11);
        }
    }
 
/*
 *  Extract data:
 */
 
    // sn
    strcpy(sn, argv[3]);
 
    // rev
    assy[0] = argv[4][8];  // grab only last 2 digits
    assy[1] = argv[4][9];
    assy[2] = '\0';
 
    // rev
    rev[0] = argv[5][1];  // drop the leading "A"
    rev[1] = argv[5][2];
    rev[2] = '\0';
 
/*
 *  Analyze and print results:
 */
 
    if(!strcmp(assy, "01")) {
        if(atoi(rev) < 12) {
            printf("%s noCr noSelFix\n", sn);
        } else {
            printf("%s noCr selFix\n", sn);
        }
    }
    if(!strcmp(assy, "04")) {
        if(atoi(rev) < 2) {
            printf("%s cr noSelFix\n", sn);
        } else {
            printf("%s cr selFix\n", sn);
        }
    }
 
    return(0);
}
