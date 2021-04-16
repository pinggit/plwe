/* File: comp-v5.c

*

* This C program compares 2 files, character by character, line by line.

*

* Written by Jonathan Natale for Juniper Networks on 9Mar07.

*

* Version History:

*    1- compiles and runs, but does not really work yet

*    4- fixed issue w/ tabs (in same place in both inputs)

*

* Caveats:

*    1- large line may crash ???

*    2- works

*    3- minor typos, close files

*    4- tabs in only one input at a given spot may cause issues

*

* To Do:

*    1- handle >2 files (use arrays)

*/

 

#define MAX_LINE_SIZE 1023

 

#include <stdio.h>

#include <ctype.h>

 

int main(int argc, char **argv) {

   FILE *fp1;

   FILE *fp2;

   char lineBuf1[MAX_LINE_SIZE];

   char lineBuf2[MAX_LINE_SIZE];

   char *line1;

   char *line2;

   int lineNum;

   int minStringLen;

   int maxStringLen;

   int i;

 

   /* command argument check: */

   if(argc != 3) {

      printf("Usage: %s <file1> <file2>\n", argv[0]);

      return(1);

   }

 

   /* open files */

   if((fp1 = fopen(argv[1], "r")) == NULL) {

      fprintf(stderr, "Cannot open file \"%s\"\n", argv[1]);

      return(2);

   }

   if((fp2 = fopen(argv[2], "r")) == NULL) {

      fprintf(stderr, "Cannot open file \"%s\"\n", argv[2]);

      return(3);

   }

 

   /* print contents of each file*/

   lineNum = 1;

   while(1) {

 

      /* get lines from each file */

      line1 = fgets(lineBuf1, 1023 - 2, fp1);

      line2 = fgets(lineBuf2, 1023 - 2, fp2);

 

      /* both files have another line */

      if((line1 != NULL) && (line2 != NULL)) {

         printf("\nline number %d:\n", lineNum++);

         printf("%s", line1);

         printf("%s", line2);

 

         /* get min/max string length */

         if(strlen(line1) < strlen(line2)) {

            minStringLen = strlen(line1);

            maxStringLen = strlen(line2);

         } else {

            minStringLen = strlen(line2);

            maxStringLen = strlen(line1);

         }

 

         /* compare each char */

         for(i=0; i<minStringLen; i++) {

            if(line1[i] == line2[i]) {

               if(line1[i] == 0x09) {

                   printf("\t");

               } else {

                   printf(" ");

               }

            } else {

               printf("^");

            }

         }

 

         /* flag extra characters as mismatch */

         for(i=minStringLen; i<maxStringLen-1; i++) {

            printf("^");

         }

         continue;

      }

 

      /* only file1 has another line */

      if((line1 != NULL) && (line2 == NULL)) {

         printf("\nline number %d:\n", lineNum++);

         printf("%s\n", line1);

 

         /* flag whole line as a mismatch */

         for(i=0; i<strlen(line1)-1; i++) {

            printf("^");

         }

         continue;

      }

 

      /* only file2 has another line */

      if((line1 == NULL) && (line2 != NULL)) {

         printf("\nline number %d:\n", lineNum++);

         printf("\n%s", line2);

 

         /* flag whole line as a mismatch */

         for(i=0; i<strlen(line2)-1; i++) {

            printf("^");

         }

         continue;

      }

 

      /* if both files have no more lines */

      break;

   }

   printf("\n");

   fclose(fp1);

   fclose(fp2);

   return(0);

}
