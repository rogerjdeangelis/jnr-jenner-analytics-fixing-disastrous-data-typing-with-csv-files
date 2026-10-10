/*---
c:/utl/jnr-jenner-analytics-fixing-disastrous-data-typing-with-csv-files.sas
---*/
Jenner Analytics fixing disastrous data typing with csv files

see
https://github.com/rogerjdeangelis/jnr-jenner-analytics-fixing-disastrous-data-typing-with-csv-files

Why importing a CSV file with Jenner Anaytics avoids disastrous sas 'proc import' data typing.

1.   You do not want all names in the sas7bdat to be 30 letters. Datastorage issue.
     We prefer the datatype for names to be more like varchar.
2.   You do not want to learn the complex sas syntax for 'proc import',
3.   You want to import the csv with one datastep that you already are familiar with.
4    You want to add BMI, Labels, and custom lengths and types.

FYI: Relative sizes for 1000 rows with alternating 32k strings  and 1000 rows with 4 byte rows.
Avro files use variable length format (varchar) for strings.
Without compression.

   1 sas7bdat   64k
   2 avro       31k  ** used in solution
   3 parquet    64k

CONTENTS

  1 PROBLEM
  2 INPUT
  3 PROCESS
  4 OUTPUT
  5 LOG

/******************************************************************************************************************/
/* 1 PROBLEM                                                                                                      */
/******************************************************************************************************************/

INPUT CSV

d:/csv/mathx.csv

name,weight,Sex,Age,Height
Amir,99,M,13,61.2
Amir,99,M,13,61.2
123456789012345678901234567890,NA,M,13,61.2

libname sd1 sas7bdat "d:/sd1";

proc import
    datafile="d:/csv/mathx.csv" /*--- complex because placement of semi-colon seems arbitrary ---*/
    out=sd1.mathx
    dbms=csv
    replace;
    guessingrows=max;
    getnames=yes;
run;

proc contents data=sd1.mathx position;
run;

Variables (in creation order):

  #  Variable  Type    Len  Format   Label
---  --------  ----  -----  -------  -----
  1  name      Char     30  $30.     /*--- Do not want every record to contain 30 byte name  ---*/
  2  weight    Char      2  $2.      /*--- Do not want weight to be character                 ---*/
  3  Sex       Char      1  $1.      /*--- wnat sex to contain  Male/Female                   ---*/
  4  Age        Num      8  BEST12.
  5  Height     Num      8  BEST12.
  6  BMI        Num      8  BEST12.  /* want to add this variable - body max index            ---*/


HERE IS THE PROBLEM WITH THE SAS7BDAT, Every occurance of name requires 30 bytes.

--- Record Number ---  18   ---  Record Length ---- 80

                                            <--- EVERY NAME IS 30 LETTERS --->
              99M.............*@......N@Amir                                  99
1...5....10...15...20...25...30...35...40...45...50...55...60...65...70...75...8
22222222222222334000000000000024999999444667222222222222222222222222222222222233
0000000000000099D0000000000000A0A99999E01D92000000000000000000000000000000000099


 --- Record Number ---  19   ---  Record Length ---- 80

                        <---   30 bytes           --->
M.............*@......N@123456789012345678901234567890        NAM...............
1...5....10...15...20...25...30...35...40...45...50...55...60...65...70...75...8
40000000000000249999994433333333333333333333333333333322222222444000000000000000
D0000000000000A0A99999E012345678901234567890123456789000000000E1D000000000000000

/******************************************************************************************************************/
/* 2 INPUT                                                                                                        */
/******************************************************************************************************************/

%utlfkil(d:/csv/mathx.csv);

options memsize=max;
data 'd:/csv/mathx.parquet';
  length name $30 weight $8;
  informat age height weight natfmt.;
  set sashelp.class(obs=3 drop=weight);
  do i=1 to 2;
    weight="99";
    output;
  end;
  name="123456789012345678901234567890";
  weight="NA";
  output;
  drop i;
  stop;
 run;

/*---
d:/csv/mathx.csv

name,weight,Sex,Age,Height
Amir,99,M,13,61.2
Amir,99,M,13,61.2
123456789012345678901234567890,NA,M,13,61.2
---*/

/******************************************************************************************************************/
/* 3 PROCESS                                                                                                      */
/******************************************************************************************************************/

options memsize=max;
libname avr avro "d:/avro";

proc delete data=avr.math;
run;

data avr.math;

  attrib
    Age     length=8   label="Age years"
    Height  length=8   label="Height inches"
    Name    length=$32 label="Student Name"
    Sex     length=$6  label="Gender"
    Weight  length=8   label="Weight pounds"
    BMI     length=8   label="Body Mass"
  ;

  informat age height weight natfmt.;

  set "d:/csv/mathx.csv";

  bmi=703*weight/height**2;

  if sex="M" then sex="Male";
  else sex="Female";

run;

proc contents data=avr.math;
run;

proc print data=avr.math;
run;

/******************************************************************************************************************/
/* 4 OUTPUT                                                                                                       */
/******************************************************************************************************************/

LIST: 12:28:34

PROC CONTENTS
-------------------------------------------------------------------------------

Data Set Name: avr.math
Observations:  3
Variables:     6

Variables (in alphabetical order):

  #  Variable  Type    Len  Format  Label
---  --------  ----  -----  ------  -------------
  1  Age        Num      8          Age years
  6  BMI        Num      8          Body Mass      /*--- ADDED VARIABLE ---*/
  2  Height     Num      8          Height inches
  3  Name      Char     32          Student Name   /*--- AS FIXED LENGTH 30 BYTES NOW VARCHAR                         ---*/
  4  Sex       Char      6          Gender         /*--- WAS M/F NOW MALE/FEMALE                                      ---*/
  5  Weight     Num      8          Weight pounds  /*--- WAS CHAR TYPE WITH PROC IMPORT ALSO CONVERTER'NA' TO MISSING ---*/

-------------------------------------------------------------------------------


  Obs  Age  Height  Name                            Sex   Weight            BMI

    1   13    61.2  Amir                            Male      99  18.5817954633
    2   13    61.2  Amir                            Male      99  18.5817954633
    3   13    61.2  123456789012345678901234567890  Male       .              .


YOU CAN SEE THE VARCHAR DATATYPE

 --- Record Number ---  21   ---  Record Length ---- 80

                                  varchar(4)
                                      ===
..h......&S..............*@.......N@..Amir..Male.......X@.^.'...2@.......*@.....
1...5....10...15...20...25...30...35...40...45...50...55...60...65...70...75...8
9969ABAFD25180A0B0000000024099999944004667004666000000C5405C28F93400000002409999
6A8B0A8BF636C8B6422000000A02A99999E0281D9228D1C52000000802E37C04202000000A02A999

 --- Record Number ---  22   ---  Record Length ---- 80 vatchar(30)
                                                      ==========================
..N@..Amir..Male.......X@.^.'...2@.......*@.......N@.<12345678901234567890123456
1...5....10...15...20...25...30...35...40...45...50...55...60...65...70...75...8
9944004667004666000000C5405C28F9340000000240999999440333333333333333333333333333
99E0281D9228D1C52000000802E37C04202000000A02A99999E02C12345678901234567890123456

--- Record Number ---  23   ---  Record Length ---- 28

7890..Male..T..h......&S....
1...5....10...15...20...25..
33330046660059969ABAFD25180A
789028D1C50046A8B0A8BF636C8B

/******************************************************************************************************************/
/* 5 OUTPUT                                                                                                       */
/******************************************************************************************************************/

NOTE: Copyright (c) 2026 Jenner Analytics Ltd., London, England.
NOTE: Jenner v1.5.97 (build v1.5.97+921fdf5fb7.20261010T011618Z)
      Licensed to Roger DeAngelis, Serial 3BF7B3E6.
NOTE: DATA _null_

autexec started.

NOTE: DATA elapsed:
  wall  0.00 seconds
  cpu   0.00 seconds
NOTE: Library WORKX assigned path=d:\wpswrkx.
NOTE: DATA workx.class

NOTE: Processing inline DATALINES (19 lines)

NOTE: Read 19 rows from DATALINES.
NOTE: The data set WORKX.CLASS has 19 observations and 5 variables.
NOTE: DATA elapsed:
  wall  0.00 seconds
  cpu   0.00 seconds
NOTE: DATA _null_

LOG:  12:38:33
NOTE: DATA _null_ completed. Output written to FILE PRINT
NOTE: Option SASAUTOS changed to c:/otojnr.
NOTE: DATA _null_

NOTE: Reading from fileref c:/jnr/runsas_selection.sas (c:/jnr/runsas_selection.sas)
    1 options memsize=max;
    2 libname avr avro "d:/avro";
    3
    4 proc delete data=avr.math;
    5 run;
    6
    7
    8 data avr.math;
    9
   10   attrib
   11     Age     length=8   label="Age years"
   12     Height  length=8   label="Height inches"
   13     Name    length=$32 label="Student Name"
   14     Sex     length=$6  label="Gender"
   15     Weight  length=8   label="Weight pounds"
   16     BMI     length=8   label="Body Mass"
   17   ;
   18
   19   informat age height weight natfmt.;
   20
   21   set "d:/csv/mathx.csv";
   22
   23   bmi=703*weight/height**2;
   24
   25   if sex="M" then sex="Male";
   26   else sex="Female";
   27
   28 run;
   29
   30 proc contents data=avr.math;
   31 run;
   32
   33 proc print data=avr.math;
   34 run;

NOTE: Read 34 rows from c:/jnr/runsas_selection.sas.
NOTE: DATA elapsed:
  wall  0.00 seconds
  cpu   0.00 seconds
NOTE: DATA _null_

autoexec completed  12:38:33

NOTE: DATA elapsed:
  wall  0.00 seconds
  cpu   0.00 seconds
NOTE: Option MEMSIZE changed to MAX.
NOTE: Library AVR assigned path=d:/avro.
NOTE: PROC DELETE datasets=avr.math

NOTE: Deleting AVR.MATH (memtype=DATA).
NOTE: 1 dataset(s) deleted.
NOTE: DATA avr.math


NOTE: Read 3 rows from d:/csv/mathx.csv.
NOTE: The data set AVR.MATH has 3 observations and 6 variables.
NOTE: DATA elapsed:
  wall  0.00 seconds
  cpu   0.00 seconds
NOTE: PROC CONTENTS data=avr.math

NOTE: PROC CONTENTS completed: 3 observations, 6 variables
NOTE: PROC PRINT data=avr.math

NOTE: PROC PRINT completed: 3 observations printed, 6 variables

/******************************************************************************************************************/
/* END                                                                                                            */
/******************************************************************************************************************/

