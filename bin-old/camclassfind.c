/* 
* file: camClassFind-generator-v0.c 
* 
* This C program generates the following eSeries LM-10 shell command: 
*  camClassFind 0x80000000,0xii0600ss,0xssssssdd,0x800000dd,0xddddpppp,0xPPPP8000 
*  ii = 
*   <classifierEngineIndex> from the "showPolicy <policyId>" eSeries SRP shell command output; 
*    <policyId> is the last hex number on the "Policy <inPolicy>..." line from the "showPolicyIds" eSeries SRP shell command output; 
*    <inPolicy> is the last word from the "ip policy input <inPolicy>" line in the "show configuration interface <interFaceTyp> <interfaceNumber>" 
*     eSeries CLI command output.  
*  ssssssss = <SA> = 
*   source ip address (default is 1.1.1.1 = 0x01010101) 
*  dddddddd = <DA> = 
*   destination ip address (default is 2.2.2.2 = 0x02020202) 
*  pppp = <SP> = 
*   source port (default is 2000 = 0x07D0 = ephemeral) 
*  ssss = <DP> = 
*   destination port (default is 25 = 0x19 = SMTP) 
* Written by Jonathan Natale for Juniper Networks on 19-Feb-11.  
* 
* ver hist 
* 0 - init 
*/ 
 
#include <stdio.h> 
#include <ctype.h> 
#include <string.h> 
 
int main(int argc, char **argv) { 
    int      i,j,k; 
    char     indexString[3]; 
    char     srcIpAddrInDottedDecimalString[16]; 
    char     srcIpAddrOctetString[4][5];     /* four octet numbers, as strings  */ 
    int      srcIpAddrOctetNum[4];           /* four octet numbers, numerically */ 
    long int srcIpAddr; 
    char     dstIpAddrInDottedDecimalString[16]; 
    char     dstIpAddrOctetString[4][5];     /* four octet numbers, as strings  */ 
    int      dstIpAddrOctetNum[4];           /* four octet numbers, numerically */ 
    long int dstIpAddr; 
    char     srcPortString[6];               /* in hex                          */ 
    int      srcPortNum; 
    char     dstPortString[6];               /* in hex                          */ 
    int      dstPortNum; 
    char     testChar; 
 
    /* 
     * basic command line arg check and online help 
     */ 
    if(argc < 2 || argc > 6 || argv[1][0] == '?' || argv[1][0] == 'h') { // '?' not working [on eng-shell1] ???  
        printf("  This C program generates the following eSeries LM-10 shell command:\n"); 
        printf("   camClassFind 0x80000000,0xii0600ss,0xssssssdd,0x800000dd,0xddddpppp,0xPPPP8000\n"); 
        printf("   ii =\n"); 
        printf("    <classifierEngineIndex> from the \"showPolicy <policyId>\" eSeries SRP shell command output;\n"); 
        printf("     <policyId> is the last hex number on the \"Policy <inPolicy>...\" line from the \"showPolicyIds\" eSeries SRP shell command output;\n"); 
        printf("     <inPolicy> is the last word from the \"ip policy input <inPolicy>\" line in the \"show configuration interface <interFaceTyp> <interfaceNumber>\"\n"); 
        printf("      sSeries CLI command output.\n"); 
        printf("   ssssssss = <SA> =\n"); 
        printf("    source ip address (default is 1.1.1.1 = 0x01010101)\n"); 
        printf("   dddddddd = <DA> =\n"); 
        printf("    destination ip address (default is 2.2.2.2 = 0x02020202)\n"); 
        printf("   pppp = <SP> =\n"); 
        printf("    source port (default is 2000 = 0x07D0 = ephemeral)\n"); 
        printf("   ssss = <DP> =\n"); 
        printf("    destination port (default is 25 = 0x19 = SMTP)\n"); 
        printf("  Refer to 2011-0111-0591, KA<tbd> and/or the \"http://www-int.juniper.net/customerservice/jtac/techdocs/ERX/docs/junose_shell_command_reference.pdf\" doc\n"); 
        printf("  Written by Jonathan Natale for Juniper Networks on 19-Feb-11.\n"); 
        printf("Usage:\n"); 
        printf(" %s <classifierEngineIndex (hex, without 0x)> [<SA (dotted decimal)> [<DA (dotted decimal)> [<SP (decimal)> [<DP (decimal)>]]]]\n", argv[0]); 
        return(1); 
    } 
 
    /* 
     * initalize default IP addresses 
     */ 
    for(i=0;i<4;i++) { 
        srcIpAddrOctetNum[i] = 1; 
    } 
    for(i=0;i<4;i++) { 
        dstIpAddrOctetNum[i] = 2; 
    } 
    srcPortNum = 2000; 
    dstPortNum = 25; 
 
   /* 
    * read and check input 
    */ 
    if(strlen(argv[1]) > 2) { 
        printf("Sorry, %s is too long (should be less then 3 chars).\n", argv[i]); 
        printf("Please try again.  Exiting ...\n"); 
        return(2); 
    } 
    for(i=0;i<strlen(argv[1]);i++) { 
        if(!isxdigit(argv[1][i])) { 
            printf("Sorry, %c is not a valid hex digit.\n", argv[1][i]); 
            printf("Please try again.  Exiting ...\n"); 
            return(3); 
        } 
    } 
    strcpy(indexString, argv[1]); 
 
    switch(argc) { 
        case 6: { 
            for(i=0;i<strlen(argv[5]);i++) { 
                if(!isdigit(argv[5][i])) { 
                    printf("Sorry, %c is not a valid dec digit.\n", argv[5][i]); 
                    printf("Please try again.  Exiting ...\n"); 
                    return(4); 
                } 
            } 
            dstPortNum = atoi(argv[5]); 
        } 
        case 5: { 
            for(i=0;i<strlen(argv[4]);i++) { 
                if(!isdigit(argv[4][i])) { 
                    printf("Sorry, %s is not a valid dec digit.\n", argv[4][i]); 
                    printf("Please try again.  Exiting ...\n"); 
                    return(5); 
                } 
            } 
            srcPortNum = atoi(argv[4]); 
        } 
        case 4: { 
            strcpy(dstIpAddrInDottedDecimalString,argv[3]); 
 
           /* 
            *  Initial sanity checks: 
            */ 
            if((strlen(dstIpAddrInDottedDecimalString) > 15) || 
               (strlen(dstIpAddrInDottedDecimalString) < 7)){ 
                printf("Sorry, %s is not a valid IP address in hex.\n", \ 
                               dstIpAddrInDottedDecimalString); 
                printf("It has the wrong number of digits"); 
                printf(" (%d, expected between 7 and 15).\n", \ 
                          strlen(dstIpAddrInDottedDecimalString)); 
                printf("Please try again.  Exiting ...\n"); 
                return(6); 
            } 
            for(i=0;i<strlen(dstIpAddrInDottedDecimalString);i++) { 
                if(!isdigit(dstIpAddrInDottedDecimalString[i]) && 
                   dstIpAddrInDottedDecimalString[i] != '.') { 
                    printf("Sorry, %s is not a valid IP address in dotted decimal.\n", \ 
                                   dstIpAddrInDottedDecimalString); 
                    printf("       "); 
                    for(j=0;j<i;j++) { 
                        printf(" "); 
                    } 
                    printf("^\n"); 
                    printf("Please try again.  Exiting ...\n"); 
                    return(7); 
                } 
            } 
 
        /* 
         *  Extract octets and do some more sanity checks: 
         */ 
            i = 0; 
            k = 0; 
            for(j=0;j<=strlen(dstIpAddrInDottedDecimalString);j++) { 
                if(dstIpAddrInDottedDecimalString[j] != '.' && 
                    dstIpAddrInDottedDecimalString[j] != '\0') { 
                    dstIpAddrOctetString[i][k++] = dstIpAddrInDottedDecimalString[j]; 
                } else { 
                    if(k < 1 || k > 3) { 
                        printf("Sorry, octet #%d has the wrong number of digits (%d).\n", i + 1, k); 
                        printf("Please try again.  Exiting ...\n"); 
                        return(8); 
                    } 
                    dstIpAddrOctetString[i][k] = '\0'; 
                    dstIpAddrOctetNum[i] = atoi(dstIpAddrOctetString[i]); 
                    if(dstIpAddrOctetNum[i] < 0 || dstIpAddrOctetNum[i] > 255) { 
                        printf("Sorry, %s contains an invalid IP octet (%d).\n", \ 
                                       dstIpAddrInDottedDecimalString, dstIpAddrOctetNum[i]); 
                        printf("It must be >= 0 and <= 255.\n"); 
                        printf("Please try again.  Exiting ...\n"); 
                        return(9); 
                    } 
                    i++; 
                    k = 0; 
                } 
            } 
            if(i!= 4) { 
                printf("Sorry, wrong number of octets (%d, expected 4)\n", i); 
                printf("Please try again.  Exiting ...\n"); 
                return(10); 
            } 
            dstIpAddr = 0; 
            for(i=0;i<3;i++) { 
                dstIpAddr = dstIpAddrOctetNum[i] | dstIpAddr; 
                dstIpAddr = dstIpAddr << 8; 
            } 
            dstIpAddr = dstIpAddrOctetNum[i] | dstIpAddr; 
        } 
        case 3: { 
            strcpy(srcIpAddrInDottedDecimalString,argv[2]); 
 
           /* 
            *  Initial sanity checks: 
            */ 
            if((strlen(srcIpAddrInDottedDecimalString) > 15) || 
               (strlen(srcIpAddrInDottedDecimalString) < 7)){ 
                printf("Sorry, %s is not a valid IP address in hex.\n", \ 
                               srcIpAddrInDottedDecimalString); 
                printf("It has the wrong number of digits"); 
                printf(" (%d, expected between 7 and 15).\n", \ 
                          strlen(srcIpAddrInDottedDecimalString)); 
                printf("Please try again.  Exiting ...\n"); 
                return(11); 
            } 
            for(i=0;i<strlen(srcIpAddrInDottedDecimalString);i++) { 
                if(!isdigit(srcIpAddrInDottedDecimalString[i]) && 
                   srcIpAddrInDottedDecimalString[i] != '.') { 
                    printf("Sorry, %s is not a valid IP address in dotted decimal.\n", \ 
                                   srcIpAddrInDottedDecimalString); 
                    printf("       "); 
                    for(j=0;j<i;j++) { 
                        printf(" "); 
                    } 
                    printf("^\n"); 
                    printf("Please try again.  Exiting ...\n"); 
                    return(12); 
                } 
            } 
 
        /* 
         *  Extract octets and do some more sanity checks: 
         */ 
            i = 0; 
            k = 0; 
            for(j=0;j<=strlen(srcIpAddrInDottedDecimalString);j++) { 
                if(srcIpAddrInDottedDecimalString[j] != '.' && 
                    srcIpAddrInDottedDecimalString[j] != '\0') { 
                    srcIpAddrOctetString[i][k++] = srcIpAddrInDottedDecimalString[j]; 
                } else { 
                    if(k < 1 || k > 3) { 
                        printf("Sorry, octet #%d has the wrong number of digits (%d).\n", i + 1, k); 
                        printf("Please try again.  Exiting ...\n"); 
                        return(13); 
                    } 
                    srcIpAddrOctetString[i][k] = '\0'; 
                    srcIpAddrOctetNum[i] = atoi(srcIpAddrOctetString[i]); 
                    if(srcIpAddrOctetNum[i] < 0 || srcIpAddrOctetNum[i] > 255) { 
                        printf("Sorry, %s contains an invalid IP octet (%d).\n", \ 
                                       srcIpAddrInDottedDecimalString, srcIpAddrOctetNum[i]); 
                        printf("It must be >= 0 and <= 255.\n"); 
                        printf("Please try again.  Exiting ...\n"); 
                        return(14); 
                    } 
                    i++; 
                    k = 0; 
                } 
            } 
            if(i!= 4) { 
                printf("Sorry, wrong number of octets (%d, expected 4)\n", i); 
                printf("Please try again.  Exiting ...\n"); 
                return(15); 
            } 
            srcIpAddr = 0; 
            for(i=0;i<3;i++) { 
                srcIpAddr = srcIpAddrOctetNum[i] | srcIpAddr; 
                srcIpAddr = srcIpAddr << 8; 
            } 
            srcIpAddr = srcIpAddrOctetNum[i] | srcIpAddr; 
        } /* end last case */ 
    } /* end switch */ 
 
   /* 
    * print results 
    */ 
    //printf("camClassFind 0x80000000,0x6060047,0xB87A04CE,0x8000002E,0xE80107D0,0x198000\n", 
    printf("camClassFind 0x80000000,0x%s0600%02.2X,0x%02.2X%02.2X%02.2X%02.2X,0x800000%02.2X,0x%02.2X%02.2X%04.4X,0x%X8000\n", 
        indexString, 
        srcIpAddrOctetNum[0], 
        srcIpAddrOctetNum[1], 
        srcIpAddrOctetNum[2], 
        srcIpAddrOctetNum[3], 
        dstIpAddrOctetNum[0], 
        dstIpAddrOctetNum[1], 
        dstIpAddrOctetNum[2], 
        dstIpAddrOctetNum[3], 
        srcPortNum, 
        dstPortNum 
    ); 
    return(0); 
} 
 
