/* Titanic data set from Kaggle, but this is supervised learning prediction. */

/* original challenge data here

https://www.kaggle.com/c/titanic/data

*/

/* 
sibsp Number of Siblings/Spouses Aboard
parch Number of Parents/Children Aboard

*/

proc import out=work.titanic1 datafile="/folders/myfolders/Titanic Project/train.csv" DBMS=CSV REPLACE;
GETNAMES=YES;
RUN;
proc print data=titanic1;
run;





/* If propTrain + propValid = 1, then no observation is assigned to testing */
%let propTrain = 0.6;         /* proportion of trainging data */
%let propValid = 0.3;         /* proportion of validation data */
%let propTest = %sysevalf(1 - &propTrain - &propValid); /* remaining are used for testing */
 
/* Randomly assign each observation to a role; _ROLE_ is indicator variable */
data RandOut;
   array p[2] _temporary_ (&propTrain, &propValid);
   array labels[3] $ _temporary_ ("Train", "Validate", "Test");
   set titanic1;
   call streaminit(123);         /* set random number seed */
   /* RAND("table") returns 1, 2, or 3 with specified probabilities */
   _k = rand("Table", of p[*]); 
   _ROLE_ = labels[_k];          /* use _ROLE_ = _k if you prefer numerical categories */
   drop _k;
run;
 
proc freq data=RandOut order=freq;
   tables _ROLE_ / nocum;
run;

/*proc print data=RandOut;
run;*/




/*create new tables*/
data train;
set RandOut (where=(_ROLE_ = 'Train'));
run;
/*proc print data=train;
run;
*/


data validate;
set RandOut (where=(_ROLE_ = 'Validate'));
run;

data test;
set RandOut (where=(_ROLE_ = 'Test'));
run;



/* Checking the frequency of the Target Variable Survived of the Train set */ 
proc freq data=work.train; table Survived; 
run;



proc logistic data=train;
class Embarked Parch Pclass Sex SibSp Survived;
model Survived(event='1') = Age Fare Embarked Parch Pclass Sex SibSp /
selection=stepwise expb stb lackfit;
output out = temp p=new;
store titanic_logistic_step;
run;



proc logistic data=train;
class Embarked Parch Pclass Sex SibSp Survived;
model Survived(event='1') = Age Fare Embarked Parch Pclass Sex SibSp /
selection=forward expb stb lackfit;
output out = temp p=new;
store titanic_logistic_forw;
run;



proc logistic data=train;
class Embarked Parch Pclass Sex SibSp Survived;
model Survived(event='1') = Age Fare Embarked Parch Pclass Sex SibSp /
selection=backward expb stb lackfit;
output out = temp p=new;
store titanic_logistic_back;
run;


/* 
based on the original dataset sex, pclass, and age are the only predictors 
that are suggested to be kept using forward, backward, and stepwise selection.
*/



/* Testing with model titanic_logistic_step */
proc plm source=titanic_logistic_step;
score data=validate out=validate1_scored predicted=p / ilink;
run;


data validate1_scored;
set validate1_scored;
if p > 0.5 then Survived_predict = 1;
else Survived_predict = 0;
keep PassengerId Survived Survived_predict;
run;
/*proc print data=validate1_scored;
run;*/



data validate1_scored;
set validate1_scored;
if Survived = 1 and Survived_predict = 1 then Success = 'True';
else if Survived = 0 and Survived_predict = 0 then Success = 'True';
else Success = 'Fail';
run;
proc print data=validate1_scored;
run;

proc freq data=validate1_scored order=freq;
   tables Success / nocum;
run;



/*
Our success rate is about 52%. This is no better than random guess.

*/















/* Checking the missing value and Statistics of the dataset */
proc means data=work.titanic1 N Nmiss mean std min P1 P5 P10 P25 P50 P75 P90 P95 P99 max;
run;

/*Checking for categorical variables: */
title “Frequency tables for categorical variables in the training set”;
proc freq data=work.titanic1 nlevels;
tables Survived; tables Sex; tables Pclass; tables SibSp; tables Parch; tables Embarked; tables Cabin;
run;


/*
There is a 177 missing age values that their observations were removed from the regression.
This could have a huge effect on the end predictions.
I will impute the missing values by using the mean.
Based on the previous stepwise, the only significant variables were sex, age, and pclass.
pclass will most likely be a better predictor of getting the mean age as there s 3
categories vs 2 categories.

The Cabin has 687 missing values. There is no way to impute this. I had noticed the huge
amount of missing values when iporting the dataset and excluded the cabin from the 
regression.

*/



/* Pclass and Age for creating boxplot */
proc sort data=work.titanic1 out=sorted;
by Pclass descending Age;
run;
title ‘Box Plot for Age vs Class’;
proc boxplot data=sorted;
plot Age*Pclass;
run;

/*
The wealthier passengers in the higher classes tend to be older, 
which logically makes sense. 
These average age values will be used to impute.
*/

/* Imputing Mean value for the age column */
data work.train2;
set work.train;
if age = '.' and Pclass = 1 then age = 37;
else if age = '.' and Pclass = 2 then age = 29;
else if age = '.' and Pclass = 3 then age = 24;
run;


data work.validate2;
set work.validate;
if age = '.' and Pclass = 1 then age = 37;
else if age = '.' and Pclass = 2 then age = 29;
else if age = '.' and Pclass = 3 then age = 24;
run;



proc logistic data=work.train2;
class Embarked Parch Pclass Sex SibSp Survived;
model Survived(event='1') = Age Fare Embarked Parch Pclass Sex SibSp /
selection=stepwise expb stb lackfit;
output out = temp p=new;
store titanic_logistic_step2;
run;



proc logistic data=work.train2;
class Embarked Parch Pclass Sex SibSp Survived;
model Survived(event='1') = Age Fare Embarked Parch Pclass Sex SibSp /
selection=forward expb stb lackfit;
output out = temp p=new;
store titanic_logistic_forw2;
run;



proc logistic data=work.train2;
class Embarked Parch Pclass Sex SibSp Survived;
model Survived(event='1') = Age Fare Embarked Parch Pclass Sex SibSp /
selection=backward expb stb lackfit;
output out = temp p=new;
store titanic_logistic_back2;
run;



/* 
Nothing changed; sex, pclass, and age are the only predictors 
that are suggested to be kept using forward, backward, and stepwise selection.
*/




/* Testing with model titanic_logistic_step2 */
proc plm source=titanic_logistic_step2;
score data=validate2 out=validate2_scored predicted=p / ilink;
run;


data validate2_scored;
set validate2_scored;
if p > 0.5 then Survived_predict = 1;
else Survived_predict = 0;
keep PassengerId Survived Survived_predict;
run;
/*proc print data=validate2_scored;
run;*/



data validate2_scored;
set validate2_scored;
if Survived = 1 and Survived_predict = 1 then Success = 'True';
else if Survived = 0 and Survived_predict = 0 then Success = 'True';
else Success = 'Fail';
run;
proc print data=validate2_scored;
run;

proc freq data=validate2_scored order=freq;
   tables Success / nocum;
run;



/*
Our success rate is about 78%. This is a lot better. With the
imputing of age we have raised the accuracy of the validation set to about
3/4 accuracy.

*/





/* Testing with model titanic_logistic_step2 using the test set*/
proc plm source=titanic_logistic_step2;
score data=test out=test_scored predicted=p / ilink;
run;


data test_scored;
set test_scored;
if p > 0.5 then Survived_predict = 1;
else Survived_predict = 0;
keep PassengerId Survived Survived_predict;
run;




data test_scored;
set test_scored;
if Survived = 1 and Survived_predict = 1 then Success = 'True';
else if Survived = 0 and Survived_predict = 0 then Success = 'True';
else Success = 'Fail';
run;
proc print data=test_scored;
run;

proc freq data=test_scored order=freq;
   tables Success / nocum;
run;

/* The test set is about the same accuracy as the validation set for
the age imputed model.




/* Exporting the output into csv file */
/*proc export data=test_scored
file=”C:/dev/projects/sas/pracdata/Result.csv” replace;
run;

*/



