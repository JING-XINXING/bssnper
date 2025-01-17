#!/usr/bin/perl -w

=head1 Name

        BS-Snper.pl  -- Detect the SNP according to the candidate positions


=head1 Version

        Author: Shengjie Gao, gaoshengjie@genomics.cn; Dan Zou, zoudan.nudt@gmail.com.

        Version: 1.0,  Date: 2014-12-23, modified: 2015-12-05

=head1 Usage

        --help      output help information to screen  

=head1 Exmple
	perl BS-Snper.pl --fa hg19.fa --input BSMAP.sort.bam --output snp.candidate.out --methcg meth.cg --methchg meth.chg --methchh meth.chh --minhetfreq 0.1 --minhomfreq 0.85 --minquali 15 --mincover 10 --maxcover 1000 --minread2 2 --errorate 0.02 --mapvalue 20 >SNP.out 2>SNP.log
	#perl BS-Snper.pl --fa hg19.fa --input sort.bam --output result --methoutput meth.out --minhetfreq 0.1 --minhomfreq 0.85   --minquali 15 --mincover 10 --maxcover 1000 --minread2 2 --errorate 0.02 >SNP.out 2>SNP.log\n
=cut


use strict;
use Getopt::Long;
use FindBin '$Bin';
use File::Path;  ## function " mkpath" and "rmtree" deal with directory
use File::Basename qw(basename dirname);
my ($Help,$fasta,$bam,$mapvalue,$minhetfreq,$minhomfreq,$minquali,$minread2,$mincover,$maxcover,$errorate,$pvalue,$interval,$output,$methcg,$methchg,$methchh);
GetOptions(
    "fa:s"=>\$fasta,
	"input:s"=>\$bam,
	"output:s"=>\$output,
	"methcg:s"=>\$methcg,
	"methchg:s"=>\$methchg,
	"methchh:s"=>\$methchh,
	"minhetfreq:i"=>\$minhetfreq,
	"minhomfreq:i"=>\$minhomfreq,
	"minquali:i"=>\$minquali,
	"mincover:i"=>\$mincover,
	"maxcover:i"=>\$maxcover,
	"minread2:i"=>\$minread2,
	"errorate:i"=>\$errorate,
	"mapvalue:i"=>\$mapvalue,
    "help"=>\$Help
);
die `pod2text $0` if (@ARGV==0 || $Help);
$minhetfreq ||=0.1;
$minhomfreq ||=0.85;
$minquali ||=15;
$mincover ||=10;
$minread2 ||=2;
$maxcover ||=1000;
$errorate ||=0.02;
$mapvalue ||=20;
#$pvalue ||=0.01;

my $eee=2.7;
# $interval = $fasta . ".len";
# if(!(-e $interval)) {
# 	system("$Bin/chrLenExtract $fasta");
# }
# if(system("$Bin/rrbsSnp $interval $fasta $bam $output $methcg $methchg $methchh $minquali $mincover $maxcover $minhetfreq $errorate $mapvalue") != 0) {
# 	die "Error!";
# }
print "#CHROM\tPOS\tID\tREF\tALT\tQUAL\tFILTER\tGENOTYPE\tFREQUENCY\tNumber_of_watson[A,T,C,G]\tNumber_of_crick[A,T,C,G]\tMean_Quality_of_Watson[A,T,C,G]\tMean_Quality_of_Crick[A,T,C,G]\n";
#chr1    10583   G       70,0,0,24       0,2,0,243       33,0,0,32       0,35,0,33
open SNP,$output or die "no snp file\n";

while(<SNP>){
 next unless(/\w/);
 next if(/^#/);
 my @a=split;
 my $geno=&genotype(\@a);
 print "\n";

# if($geno eq "REF"){
	#print STDERR join("\t", @a)."\n";
 # }elsif($geno==0){
	#print STDERR "reference is N @a\n";
  #}else{
	#print $geno;	
  #}  
}

print "SNP finished\n";
#chr1    10583   G       70,0,0,24       0,2,0,243       33,0,0,32       0,35,0,33
#$minfreq,$minquali,$minread2,$mincover,$pvalue,$interval
sub genotype
{
	my $line=shift;
	my @lines=@{$line};
	my $genoreturn=&Bayes($line);
	my @bayes=split /\t/,$genoreturn;
	my $genoqual=$bayes[1];
	my $genotypemaybe=$bayes[0];
	my @watson=split /\,/,$lines[3];
	my @crick=split /\,/,$lines[4];
	my @wsq=split /\,/,$lines[5];
	my @crq=split /\,/,$lines[6];
	#print "$lines[0]\t$lines[1]\t$lines[2]\t$genotypemaybe\n";
	my $totaldepth=$watson[0]+$watson[1]+$watson[2]+$watson[3]+$crick[0]+$crick[1]+$crick[2]+$crick[3];
	if($genotypemaybe eq "AA"){#genotypeis AA
		if($lines[2] =~/A/i){
			return "REF";	
		}
		if($lines[2] =~/T/i){#T>AA       reference is T
			my $qvalue=($wsq[0]>$crq[0])?$wsq[0]:$crq[0];
			my $depth=$watson[0]+$crick[0]+$watson[1]+$crick[1];
			my $var=$watson[0]+$crick[0];
			
			if($depth >= $mincover  && $qvalue >= $minquali && $var >=$minread2 ){
				#sprintf("%.2f", $f)
				my $T2A=sprintf("%.3f",$var/$totaldepth);
				if($T2A>=$minhomfreq){
					print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tPASS\tAA\t$T2A\t".join("\t",@lines[3..6])."\n";
				}else{
					print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAA\t$T2A\t".join("\t",@lines[3..6])."\n";
				}
				
			}else{
				my $T2A=sprintf("%.3f",$var/$totaldepth);				
				print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAA\t$T2A\t".join("\t",@lines[3..6])."\n";
			}									
		}
		if($lines[2] =~/C/i){#C>AA
			my $qvalue=($wsq[0]>$crq[0])?$wsq[0]:$crq[0];
			my $depth=$watson[2]+$crick[2]+$watson[0]+$crick[0];
            my $var=$watson[0]+$crick[0];	
			
			if($depth >= $mincover  && $qvalue >= $minquali && $var >=$minread2 ){
                                my $C2A=sprintf("%.3f",$var/$totaldepth);
                                if($C2A>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tPASS\tAA\t$C2A\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAA\t$C2A\t".join("\t",@lines[3..6])."\n";
                                }   
    
                        }else{
				my $C2A=sprintf("%.3f",$var/$totaldepth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAA\t$C2A\t".join("\t",@lines[3..6])."\n";
                        } 					
		}

		if($lines[2] =~/G/i){#G>AA
			my $qvalue=$wsq[0];
                        my $depth=$watson[3]+$watson[0];
                        my $var=$watson[0];
			my $G2A;
			if($depth>0){
				$G2A=sprintf("%.3f",$var/$totaldepth);
			}else{
				$G2A=0;
			}

                        if($depth >= $mincover  && $qvalue >= $minquali && $var >=$minread2 ){
                                if($G2A>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tPASS\tAA\t$G2A\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAA\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAA\t$G2A\t".join("\t",@lines[3..6])."\n";
                        }
		}
	}

	if($genotypemaybe eq "AT"){ #genotype is AT
		if($lines[2] =~/A/i){#A>AT
           		my $qvalue=($wsq[1]>$crq[1])?$wsq[1]:$crq[1];;
			my $depth=$watson[0]+$watson[1]+$crick[0]+$crick[1];
			my $var=$watson[1]+$crick[1];	
			
			if($depth >= $mincover  && $qvalue >= $minquali && $var >=$minread2 ){
                                my $A2T=sprintf("%.3f",$var/$totaldepth);
                                if($A2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tPASS\tAT\t$A2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tAT\t$A2T\t".join("\t",@lines[3..6])."\n";
                                }
                        }else{
				my $A2T=sprintf("%.3f",$var/$totaldepth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tAT\t$A2T\t".join("\t",@lines[3..6])."\n";
                        } 
                }   

                if($lines[2] =~/T/i){#T>AT			
            		my $qvalue=($wsq[0]>$crq[0])?$wsq[0]:$crq[0];
                        my $depth=$watson[0]+$watson[1]+$crick[0]+$crick[1];
                        my $var=$crick[0]+$watson[0];
                        
                        if($depth >= $mincover  && $qvalue >= $minquali && $var >=$minread2 ){
                                my $T2A=sprintf("%.3f",$var/$totaldepth);
                                if($T2A>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tPASS\tAT\t$T2A\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAT\t$T2A\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
				my $T2A=sprintf("%.3f",$var/$totaldepth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAT\t$T2A\t".join("\t",@lines[3..6])."\n";
                        }
                }   
                if($lines[2] =~/C/i){#C>AT
			my $qvalueA=($wsq[0]>$crq[0])?$wsq[0]:$crq[0];
			my $qvalueT=$crq[1];
			my $varA=$watson[0]+$crick[0];
			my $varT=$crick[1];
			my $depth=$watson[0]+$crick[0]+$crick[1];
			
			if($depth >= $mincover  && $qvalueA >= $minquali && $qvalueT>=$minquali && $varA >=$minread2 && $varT>=$minread2 ){
                                my $C2A=sprintf("%.3f",$varA/$totaldepth);
				my $C2T=sprintf("%.3f",$varT/$totaldepth);
                                if($C2A>=$minhetfreq && $C2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAT\t$genoqual\tPASS\tAT\t$C2A\,$C2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAT\t$genoqual\tLow\tAT\t$C2A\,$C2T\t".join("\t",@lines[3..6])."\n";
                                }   

                        }else{
                                my $C2A=sprintf("%.3f",$varT/$totaldepth);
                                my $C2T=sprintf("%.3f",$varT/$totaldepth);
				print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAT\t$genoqual\tLow\tAT\t$C2A\,$C2T\t".join("\t",@lines[3..6])."\n";
                        }  		
			
                }   
                if($lines[2] =~/G/i){#G>AT	
			my $qvalueA=$wsq[0];
                        my $qvalueT=($wsq[1]>$crq[1])?$wsq[1]:$crq[1];
                        my $varA=$watson[0];
                        my $varT=$crick[1]+$watson[1];
                        my $depth=$watson[0]+$crick[1]+$watson[1];

                        if($depth >= $mincover  && $qvalueA >= $minquali && $qvalueT>=$minquali && $varA >=$minread2 && $varT>=$minread2 ){
                                my $G2A=sprintf("%.3f",$varA/$totaldepth);
                                my $G2T=sprintf("%.3f",$varT/$totaldepth);
                                if($G2A>=$minhetfreq && $G2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAT\t$genoqual\tPASS\tAT\t$G2A\,$G2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAT\t$genoqual\tLow\tAT\t$G2A\,$G2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $G2A=sprintf("%.3f",$varA/$totaldepth);
                                my $G2T=sprintf("%.3f",$varT/$totaldepth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAT\t$genoqual\tLow\tAT\t$G2A\,$G2T\t".join("\t",@lines[3..6])."\n";
                        }
				
                }   				
	}
#AC	
	if($genotypemaybe eq "AC"){ #genotype is AC
                if($lines[2] =~/A/i){ #A>AC
                        my $qvalueC=($wsq[2]>$crq[2])?$wsq[2]:$crq[2];
                        my $varC=$watson[2]+$crick[2];
                        my $depth=$watson[0]+$crick[2]+$watson[2];
			my $A2C=sprintf("%.3f",$varC/$totaldepth);
                        if($depth >= $mincover  && $qvalueC >= $minquali  && $varC >=$minread2 ){
                                if($A2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tPASS\tAC\t$A2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tAC\t$A2C\t".join("\t",@lines[3..6])."\n";
                                }   

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tAC\t$A2C\t".join("\t",@lines[3..6])."\n";
                        }   			
                }
                if($lines[2] =~/T/i){#T>AC ############modify totaldepth
			my $qvalueA=($wsq[0]>$crq[0])?$wsq[0]:$crq[0];
                        my $qvalueC=($wsq[2]>$crq[2])?$wsq[2]:$crq[2];
                        my $varA=$watson[0]+$crick[0];
                        my $varC=$crick[2]+$watson[2];
                        my $depth=$watson[0]+$crick[2]+$watson[2]+$crick[0]+$crick[1];
			my $T2A=sprintf("%.3f",$varA/$totaldepth);
                        my $T2C=sprintf("%.3f",$varC/$totaldepth);
                        if($depth >= $mincover  && $qvalueA >= $minquali && $qvalueC>=$minquali && $varA >=$minread2 && $varC>=$minread2 ){
                                if($T2A>=$minhetfreq && $T2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAC\t$genoqual\tPASS\tAC\t$T2A\,$T2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAC\t$genoqual\tLow\tAC\t$T2A\,$T2C\t".join("\t",@lines[3..6])."\n";
                                }   

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAC\t$genoqual\tLow\tAC\t$T2A\,$T2C\t".join("\t",@lines[3..6])."\n";
                        }       
		
                }
                if($lines[2] =~/C/i){#C>AC
			my $qvalueA=($wsq[0]>$crq[0])?$wsq[0]:$crq[0];
                        my $varA=$watson[0]+$crick[0];
                        my $depth=$watson[0]+$crick[2]+$watson[2];
                        my $C2A=sprintf("%.3f",$varA/$totaldepth);
                        if($depth >= $mincover  && $qvalueA >= $minquali  && $varA >=$minread2 ){
                                if($C2A>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tPASS\tAC\t$C2A\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAC\t$C2A\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAC\t$C2A\t".join("\t",@lines[3..6])."\n";
                        }			
                }
                if($lines[2] =~/G/i){#G>AC
			my $qvalueA=$wsq[0];
                        my $qvalueC=($wsq[2]>$crq[2])?$wsq[2]:$crq[2];
                        my $varA=$watson[0];
                        my $varC=$crick[2]+$watson[2];
                        my $depth=$watson[0]+$crick[2]+$watson[2]+$crick[0];
                        my $G2A=sprintf("%.3f",$varA/$totaldepth);
                        my $G2C=sprintf("%.3f",$varC/$totaldepth);
                        if($depth >= $mincover  && $qvalueA >= $minquali && $qvalueC>=$minquali && $varA >=$minread2 && $varC>=$minread2 ){
                                if($G2A>=$minhetfreq && $G2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAC\t$genoqual\tPASS\tAC\t$G2A\,$G2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAC\t$genoqual\tLow\tAC\t$G2A\,$G2C\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAC\t$genoqual\tLow\tAC\t$G2A\,$G2C\t".join("\t",@lines[3..6])."\n";
                        }
                }
        }   
	
#AG	
	if($genotypemaybe eq "AG"){
                if($lines[2] =~/A/i){#A>AG
			my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $varG=$watson[3]+$crick[3];
                        my $depth=$watson[0]+$crick[3]+$watson[3]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
                        my $A2G=sprintf("%.3f",$varG/$depth);
                        if($depth >= $mincover  && $qvalueG >= $minquali  && $varG >=$minread2 ){
                                if($A2G>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tPASS\tAG\t$A2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tAG\t$A2G\t".join("\t",@lines[3..6])."\n";
                                }   

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tAC\t$A2G\t".join("\t",@lines[3..6])."\n";
                        }    			
                }
                if($lines[2] =~/T/i){#T>AG
			my $qvalueA=$wsq[0];
                        my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $varA=$watson[0];
                        my $varG=$crick[3]+$watson[3];
                        my $depth=$watson[0]+$crick[3]+$watson[3]+$crick[0]+$crick[1]+$watson[1];
                        my $T2A=sprintf("%.3f",$varA/$totaldepth);
                        my $T2G=sprintf("%.3f",$varG/$totaldepth);
                        if($depth >= $mincover  && $qvalueA >= $minquali && $qvalueG>=$minquali && $varA >=$minread2 && $varG>=$minread2 ){
                                if($T2A>=$minhetfreq && $T2G>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAG\t$genoqual\tPASS\tAG\t$T2A\,$T2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAG\t$genoqual\tLow\tAG\t$T2A\,$T2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAG\t$genoqual\tLow\tAG\t$T2A\,$T2G\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
                if($lines[2] =~/C/i){#C>AG
			my $qvalueA=$wsq[0];
                        my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $varA=$watson[0];
                        my $varG=$crick[3]+$watson[3];
                        my $depth=$watson[0]+$crick[2]+$watson[2]+$crick[0]+$crick[1]+$watson[1];
                        my $C2A=sprintf("%.3f",$varA/$totaldepth);
                        my $C2G=sprintf("%.3f",$varG/$totaldepth);
                        if($depth >= $mincover  && $qvalueA >= $minquali && $qvalueG>=$minquali && $varA >=$minread2 && $varG>=$minread2 ){
                                if($C2A>=$minhetfreq && $C2G>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAG\t$genoqual\tPASS\tAG\t$C2A\,$C2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAG\t$genoqual\tLow\tAG\t$C2A\,$C2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tAG\t$genoqual\tLow\tAG\t$C2A\,$C2G\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
                if($lines[2] =~/G/i){#G>AG
			my $qvalueA=$wsq[0];
                        my $varA=$watson[0];
                        my $depth=$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
                        my $G2A=sprintf("%.3f",$varA/$depth);
                        if($depth >= $mincover  && $qvalueA >= $minquali  && $varA >=$minread2 ){
                                if($G2A>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tPASS\tAG\t$G2A\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAG\t$G2A\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tA\t$genoqual\tLow\tAG\t$G2A\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
        }   
#TT
	if($genotypemaybe eq "TT"){
                if($lines[2] =~/A/i){#A>TT
			my $qvalueT=$crq[1];
                        my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $varT=$crick[1];

                        if($depth >= $mincover  && $qvalueT >= $minquali && $varT >=$minread2 ){
                                my $A2T=sprintf("%.3f",$varT/$totaldepth);
                                if($A2T>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tPASS\tTT\t$A2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tTT\t$A2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $A2T=sprintf("%.3f",$varT/$totaldepth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tTT\t$A2T\t".join("\t",@lines[3..6])."\n";
                        }
                }
                if($lines[2] =~/T/i){
			return "REF"; 
                }
                if($lines[2] =~/C/i){#C>TT
			my $qvalueT=$crq[1];
                        my $depth=$crick[1]+$crick[3];
                        my $varT=$crick[1];
			my $C2T;
			if($depth>0){
				$C2T=sprintf("%.3f",$varT/$depth);

			}else{
				$C2T=0;
				
			}
			
                        if($depth >= $mincover  && $qvalueT >= $minquali && $varT >=$minread2 ){
                                if($C2T>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tPASS\tTT\t$C2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tTT\t$C2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tTT\t$C2T\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
                if($lines[2] =~/G/i){#G>TT
			my $qvalueT=$crq[1];
                        my $depth=$watson[3]+$crick[3]+$crick[1];
                        my $varT=$crick[1]+$watson[1];

                        if($depth >= $mincover  && $qvalueT >= $minquali && $varT >=$minread2 ){
                                my $G2T=sprintf("%.3f",$varT/$totaldepth);
                                if($G2T>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tPASS\tTT\t$G2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tTT\t$G2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $G2T=sprintf("%.3f",$varT/$totaldepth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tTT\t$G2T\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
        }  

#CC     
        if($genotypemaybe eq "CC"){
                if($lines[2] =~/A/i){#A>CC
			my $qvalueC=($crq[2]>$wsq[2])?$crq[2]:$wsq[2];
                        my $depth=$watson[0]+$crick[0]+$crick[2]+$watson[2]+$watson[3]+$watson[3]+$crick[1];
                        my $varC=$watson[2]+$crick[2];

                        if($depth >= $mincover  && $qvalueC >= $minquali && $varC >=$minread2 ){
                                my $A2C=sprintf("%.3f",$varC/$depth);
                                if($A2C>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tPASS\tCC\t$A2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCC\t$A2C\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $A2C=sprintf("%.3f",$varC/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCC\t$A2C\t".join("\t",@lines[3..6])."\n";
                        }	
                }   
                if($lines[2] =~/T/i){#T>CC
			my $qvalueC=($crq[2]>$wsq[2])?$crq[2]:$wsq[2];
                        my $depth=$crick[1]+$crick[2]+$watson[2]+$watson[0]+$crick[0]+$watson[3]+$crick[3];
                        my $varC=$watson[2]+$crick[2];

                        if($depth >= $mincover  && $qvalueC >= $minquali && $varC >=$minread2 ){
                                my $T2C=sprintf("%.3f",$varC/$depth);
                                if($T2C>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tPASS\tCC\t$T2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCC\t$T2C\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $T2C=sprintf("%.3f",$varC/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCC\t$T2C\t".join("\t",@lines[3..6])."\n";
                        }

                }   
                if($lines[2] =~/C/i){#C>CC  
			return "REF";
                }   
                if($lines[2] =~/G/i){#G>CC
			my $qvalueC=($crq[2]>$wsq[2])?$crq[2]:$wsq[2];
                        my $depth=$watson[3]+$crick[3]+$crick[2]+$watson[2]+$watson[0]+$crick[0]+$crick[1];
                        my $varC=$watson[2]+$crick[2];

                        if($depth >= $mincover  && $qvalueC >= $minquali && $varC >=$minread2 ){
                                my $G2C=sprintf("%.3f",$varC/$depth);
                                if($G2C>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tPASS\tCC\t$G2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCC\t$G2C\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $G2C=sprintf("%.3f",$varC/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCC\t$G2C\t".join("\t",@lines[3..6])."\n";
                        }
                }   
        }   
#GG    
        if($genotypemaybe eq "GG"){
                if($lines[2] =~/A/i){#A>GG
			my $qvalueG=($crq[3]>$wsq[3])?$crq[3]:$wsq[3];
                        my $depth=$watson[0]+$crick[3]+$watson[3]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
                        my $varG=$watson[3]+$crick[3];

                        if($depth >= $mincover  && $qvalueG >= $minquali && $varG >=$minread2 ){
                                my $A2G=sprintf("%.3f",$varG/$depth);
                                if($A2G>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tPASS\tGG\t$A2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGG\t$A2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $A2G=sprintf("%.3f",$varG/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGG\t$A2G\t".join("\t",@lines[3..6])."\n";
                        }
			
                }   
                if($lines[2] =~/T/i){#T>GG
			my $qvalueG=($crq[3]>$wsq[3])?$crq[3]:$wsq[3];
                        my $depth=$crick[1]+$watson[1]+$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1];
                        my $varG=$watson[3]+$crick[3];

                        if($depth >= $mincover  && $qvalueG >= $minquali && $varG >=$minread2 ){
                                my $T2G=sprintf("%.3f",$varG/$depth);
                                if($T2G>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tPASS\tGG\t$T2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGG\t$T2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $T2G=sprintf("%.3f",$varG/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGG\t$T2G\t".join("\t",@lines[3..6])."\n";
                        }
	
                } 

  
                if($lines[2] =~/C/i){#C>GG
			my $qvalueG=($crq[3]>$wsq[3])?$crq[3]:$wsq[3];
                        my $depth=$crick[1]+$watson[1]+$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1];
                        my $varG=$watson[3]+$crick[3];

                        if($depth >= $mincover  && $qvalueG >= $minquali && $varG >=$minread2 ){
                                my $C2G=sprintf("%.3f",$varG/$depth);
                                if($C2G>=$minhomfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tPASS\tGG\t$C2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGG\t$C2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $C2G=sprintf("%.3f",$varG/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGG\t$C2G\t".join("\t",@lines[3..6])."\n";
                        }
	
                }   
                if($lines[2] =~/G/i){
			return "REF";
                }   
        }    
#CT	
	if($genotypemaybe eq "CT"){
                if($lines[2] =~/A/i){#A>CT
			my $qvalueC=($wsq[2]>$crq[2])?$wsq[2]:$crq[2];
                        my $qvalueT=$crq[1];
                        my $varC=$watson[2]+$crick[2];
                        my $varT=$crick[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
			my $depth=$totaldepth-$watson[1];
                        if($depth >= $mincover  && $qvalueC >= $minquali && $qvalueT>=$minquali && $varC >=$minread2 && $varT>=$minread2 ){
                                my $A2C=sprintf("%.3f",$varC/$depth);
                                my $A2T=sprintf("%.3f",$varT/$depth);
                                if($A2C>=$minhetfreq && $A2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCT\t$genoqual\tPASS\tCT\t$A2C\,$A2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCT\t$genoqual\tLow\tCT\t$A2C\,$A2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $A2C= sprintf("%.3f",$varC/$depth);
                                my $A2T= sprintf("%.3f",$varT/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCT\t$genoqual\tLow\tCT\t$A2C\,$A2T\t".join("\t",@lines[3..6])."\n";
                        }

                }
                if($lines[2] =~/T/i){ #T>CT
			my $qvalueC=($wsq[2]>$crq[2])?$wsq[2]:$crq[2];
                        my $varC=$watson[2]+$crick[2];
                        #my $depth=$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
			my $depth=$totaldepth-$watson[1];
                        my $T2C= sprintf("%.3f",$varC/$depth);
                        if($depth >= $mincover  && $qvalueC >= $minquali  && $varC >=$minread2 ){
                                if($T2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tPASS\tCT\t$T2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCT\t$T2C\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tCT\t$T2C\t".join("\t",@lines[3..6])."\n";
                        }
                }
                if($lines[2] =~/C/i){ #C>CT
			my $qvalueT=$crq[1];
                        my $varT=$crick[1];
                        #my $depth=$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
                        my $depth=$totaldepth-$watson[1];
                        my $C2T=sprintf("%.3f",$varT/$depth);
                        if($depth >= $mincover  && $qvalueT >= $minquali  && $varT >=$minread2 ){
                                if($C2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tPASS\tCT\t$C2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tCT\t$C2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tCT\t$C2T\t".join("\t",@lines[3..6])."\n";
                        }

                }
                if($lines[2] =~/G/i){#G>CT
			my $qvalueC=($wsq[2]>$crq[2])?$wsq[2]:$crq[2];
                        my $qvalueT=$crq[1];
                        my $varC=$watson[2]+$crick[2];
                        my $varT=$crick[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$totaldepth-$watson[1];
                        if($depth >= $mincover  && $qvalueC >= $minquali && $qvalueT>=$minquali && $varC >=$minread2 && $varT>=$minread2 ){
                                my $G2C=sprintf("%.3f",$varC/$depth);
                                my $G2T=sprintf("%.3f",$varT/$depth);
                                if($G2C>=$minhetfreq && $G2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCT\t$genoqual\tPASS\tCT\t$G2C\,$G2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCT\t$genoqual\tLow\tCT\t$G2C\,$G2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $G2C= sprintf("%.3f",$varC/$depth);
                                my $G2T= sprintf("%.3f",$varT/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCT\t$genoqual\tLow\tCT\t$G2C\,$G2T\t".join("\t",@lines[3..6])."\n";
                        }			
                }
        }   
#GT
	if($genotypemaybe eq "GT"){
                if($lines[2] =~/A/i){ #A>GT
			my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $qvalueT=$crq[1];
                        my $varG=$watson[3]+$crick[3];
                        my $varT=$crick[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$totaldepth-$watson[1]-$crick[0];
                        if($depth >= $mincover  && $qvalueG >= $minquali && $qvalueT>=$minquali && $varG >=$minread2 && $varT>=$minread2 ){
                                my $A2G= sprintf("%.3f",$varG/$depth);
                                my $A2T= sprintf("%.3f",$varT/$depth);
                                if($A2G>=$minhetfreq && $A2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tGT\t$genoqual\tPASS\tGT\t$A2G\,$A2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tGT\t$genoqual\tLow\tGT\t$A2G\,$A2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $A2G= sprintf("%.3f",$varG/$depth);
                                my $A2T= sprintf("%.3f",$varT/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tGT\t$genoqual\tLow\tGT\t$A2G\,$A2T\t".join("\t",@lines[3..6])."\n";
                        }

                }
                if($lines[2] =~/T/i){#T>G
			my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $varG=$watson[3]+$crick[3];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$watson[0]+$watson[1]+$watson[2]+$watson[3]+$crick[1]+$crick[2]+$crick[3];
                        if($depth >= $mincover  && $qvalueG >= $minquali  && $varG >=$minread2 ){
                                my $T2G= sprintf("%.3f",$varG/$depth);
                                if($T2G>=$minhetfreq ){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tPASS\tGT\t$T2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGT\t$T2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $T2G= sprintf("%.3f",$varG/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tGT\t$T2G\t".join("\t",@lines[3..6])."\n";
                        }	
                }
                if($lines[2] =~/C/i){#C>GT
			my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $qvalueT=$crq[1];
                        my $varG=$watson[3]+$crick[3];
                        my $varT=$crick[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$totaldepth-$watson[1]-$crick[0];
                        if($depth >= $mincover  && $qvalueG >= $minquali && $qvalueT>=$minquali && $varG >=$minread2 && $varT>=$minread2 ){
                                my $C2G= sprintf("%.3f",$varG/$depth);
                                my $C2T= sprintf("%.3f",$varT/$depth);
                                if($C2G>=$minhetfreq && $C2T>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tGT\t$genoqual\tPASS\tGT\t$C2G\,$C2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tGT\t$genoqual\tLow\tGT\t$C2G\,$C2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $C2G= sprintf("%.3f",$varG/$depth);
                                my $C2T= sprintf("%.3f",$varT/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tGT\t$genoqual\tLow\tGT\t$C2G\,$C2T\t".join("\t",@lines[3..6])."\n";
                        }

                }
                if($lines[2] =~/G/i){#G>GT
			my $qvalueT=$crq[1];
                        my $varT=$crick[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$totaldepth;
                        if($depth >= $mincover  && $qvalueT >= $minquali  && $varT >=$minread2 ){
                                my $G2T= sprintf("%.3f",$varT/$depth);
                                if($G2T>=$minhetfreq ){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tPASS\tGT\t$G2T\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tGT\t$G2T\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $G2T= sprintf("%.3f",$varT/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tT\t$genoqual\tLow\tGT\t$G2T\t".join("\t",@lines[3..6])."\n";
                        }
                }
        }   
#CG
	if($genotypemaybe eq "CG"){
                if($lines[2] =~/A/i){#A>CG
			my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $qvalueC=($wsq[1]>$crq[1])?$wsq[1]:$crq[1];
                        my $varG=$watson[3]+$crick[3];
                        my $varC=$crick[1]+$watson[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$totaldepth-$watson[1]-$crick[0];
                        if($depth >= $mincover  && $qvalueG >= $minquali && $qvalueC>=$minquali && $varG >=$minread2 && $varC>=$minread2 ){
                                my $A2G= sprintf("%.3f",$varG/$depth);
                                my $A2C= sprintf("%.3f",$varC/$depth);
                                if($A2G>=$minhetfreq && $A2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCG\t$genoqual\tPASS\tCG\t$A2C\,$A2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCG\t$genoqual\tLow\tCG\t$A2C\,$A2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $A2G= sprintf("%.3f",$varG/$depth);
                                my $A2C= sprintf("%.3f",$varC/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCG\t$genoqual\tLow\tCG\t$A2G\,$A2C\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
                if($lines[2] =~/T/i){#T>CG
			my $qvalueG=($wsq[3]>$crq[3])?$wsq[3]:$crq[3];
                        my $qvalueC=($wsq[1]>$crq[1])?$wsq[1]:$crq[1];
                        my $varG=$watson[3]+$crick[3];
                        my $varC=$crick[1]+$watson[1];
                        #my $depth=$watson[0]+$crick[0]+$crick[1];
                        my $depth=$totaldepth-$watson[1]-$crick[0];
                        if($depth >= $mincover  && $qvalueG >= $minquali && $qvalueC>=$minquali && $varG >=$minread2 && $varC>=$minread2 ){
                                my $T2G= sprintf("%.3f",$varG/$depth);
                                my $T2C= sprintf("%.3f",$varC/$depth);
                                if($T2G>=$minhetfreq && $T2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCG\t$genoqual\tPASS\tCG\t$T2C\,$T2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCG\t$genoqual\tLow\tCG\t$T2C\,$T2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                my $T2G= sprintf("%.3f",$varG/$depth);
                                my $T2C= sprintf("%.3f",$varC/$depth);
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tCG\t$genoqual\tLow\tCG\t$T2G\,$T2C\t".join("\t",@lines[3..6])."\n";
                        }
                }
                if($lines[2] =~/C/i){#C>CG
			my $qvalueG=$wsq[3];
                        my $varG=$watson[3];
                        #my $depth=$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
                        my $depth=$totaldepth-$watson[1]-$crick[0];
                        my $C2G= sprintf("%.3f",$varG/$depth);
                        if($depth >= $mincover  && $qvalueG >= $minquali  && $varG >=$minread2 ){
                                if($C2G>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tPASS\tCG\t$C2G\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tCG\t$C2G\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tG\t$genoqual\tLow\tCG\t$C2G\t".join("\t",@lines[3..6])."\n";
                        }			
                }
                if($lines[2] =~/G/i){#G>CG
			my $qvalueC=$crq[2];
                        my $varC=$crick[2];
                        #my $depth=$crick[3]+$watson[3]+$watson[0]+$watson[1]+$crick[1]+$watson[2]+$crick[2];
                        my $depth=$totaldepth-$watson[1]-$crick[0];
                        my $G2C= sprintf("%.3f",$varC/$depth);
                        if($depth >= $mincover  && $qvalueC >= $minquali  && $varC >=$minread2 ){
                                if($G2C>=$minhetfreq){
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tPASS\tCG\t$G2C\t".join("\t",@lines[3..6])."\n";
                                }else{
                                        print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCG\t$G2C\t".join("\t",@lines[3..6])."\n";
                                }

                        }else{
                                print "$lines[0]\t$lines[1]\t\.\t$lines[2]\tC\t$genoqual\tLow\tCG\t$G2C\t".join("\t",@lines[3..6])."\n";
                        }
	
                }
        }   
	unless($lines[2]=~/[ACGT]/i){
        print "[ACGT]\n";
		return 0;
		#print "$lines[0]\t$lines[1]\t\.\t$lines[2]\t0\tSuper\tNN\t\.\t".join("\t",@lines[3..6])."\n";
	}

}


sub Bayes
{
	my $line=shift;
        my @lines=@{$line};
        #print "$line[0]\n";
	my $refbase=$lines[2];
        my @watson=split /\,/,$lines[3];
        my @crick=split /\,/,$lines[4];
        my @wsq=split /\,/,$lines[5];
        my @crq=split /\,/,$lines[6];
	my $ptransition=0.00066;
	my $ptransversion=0.00033;
	#error of base
    
	my $baseqWA=sprintf("%.3e",0.1**($wsq[0]/10));
	my $baseqCA=sprintf("%.3e",0.1**($crq[0]/10));
	my $baseqWT=sprintf("%.3e",0.1**($wsq[1]/10));
	my $baseqCT=sprintf("%.3e",0.1**($crq[1]/10));
	my $baseqWC=sprintf("%.3e",0.1**($wsq[2]/10));
    my $baseqCC=sprintf("%.3e",0.1**($crq[2]/10));
	my $baseqWG=sprintf("%.3e",0.1**($wsq[3]/10));
    my $baseqCG=sprintf("%.3e",0.1**($crq[3]/10));
	my $gntpmaybe; my $qualerr;	
	my @totalproduct = sort{$a<=>$b} ($baseqWA,$baseqCA,$baseqWT, $baseqCT, $baseqWC, $baseqCC, $baseqWG, $baseqCG);
	if($totalproduct[0]==0 ){
		$gntpmaybe="NN";
		$qualerr=0;	
		return "$gntpmaybe\t$qualerr"; 
	}


	#P(Di|g=Gj)
	my $nn=&Factorial($watson[0],$crick[1],$crick[2],$watson[3]);
	my ($aa,$ac,$at,$ag,$cc,$cg,$ct,$gg,$gt,$tt);
	$aa=$ac=$at=$ag=$cc=$cg=$ct=$gg=$gt=$tt=0;
	if($wsq[0]>0 ){#######A>0
		my $a_aa=1-$baseqWA;
		my $other=$baseqWA/3;
		
		my $nn=&Factorial($watson[0],$crick[1],$crick[2],$watson[3]);
		
		$aa = $nn+ $watson[0]*log($a_aa) + ($crick[1]+$watson[1]+$watson[2]+$crick[2]+$watson[3]+$crick[3])*log($other) ;
		if($crick[1]>0){#AT
			my $a_at=(1-($baseqWA+$baseqCT)/2)/2;#provid genotype is AT, the probility to find A.
			$other=($baseqWA+$baseqCT)/4;#the probability of other 2 types opear if genotype is AT. 
			$at = $nn+ ($watson[0]+$crick[1])*log($a_at) + ($crick[2]+$watson[3]+$watson[2]+$crick[3])*log($other);
		}
		if($crick[2]>0 || $watson[2]>0){#AC
			my $a_ac= (1-$baseqWA)/2;
			$other=$baseqWA/3;
			$ac = $nn+ ($watson[0]+$watson[2]+$crick[2])*log($a_ac) +  ($crick[1]+$watson[3]+$crick[3])*log($other);
		}  
		if($crick[3]>0 || $watson[3]>0){#AG
			my $a_ag=(1-$baseqWA)/2;
			$other=$baseqWA/3;
			$ag = $nn+ ($watson[0]+$watson[3]+$crick[3])*log($a_ag) + ($crick[2]+$crick[1]+$watson[2])*log($other);
		}
	}
	if($crq[1]>0 ){###filter wsq[1]>0 but crq[1]==0
		my $t_tt=1-$baseqCT;
		#my $t_gt=(1-($baseqCT+$baseqWG)/2)/2;
		my $other = $baseqCT/3;
		#type TT
		$tt= $nn + $crick[1]*log($t_tt)+ ($watson[0]+$crick[2]+$watson[3]+$crick[3]+$watson[2])*log($other);
		if($watson[2]>0 || $crick[2]>0){
			my $t_ct=(1-$baseqCT)/2;
			$other=$baseqCT/3; 
			##typeCT
			$ct= $nn + ($watson[2]+$crick[1]+$crick[2])*log($t_ct) + ($watson[0]+$watson[3]+$crick[3])*log($other);
		}
		if($watson[3]>0 || $crick[3]>0){
			my $t_gt=(1-$baseqCT)/2;
			$other=$baseqCT/3;
			$gt= $nn + ($crick[1]+$watson[3]+$crick[3]) * log($t_gt) + ($watson[0]+$crick[2]+$watson[2])*log($other);	 
		}
	}	

	if($crq[2]>0 || $wsq[2]>0){#CC CG
		my $baseqC=($baseqCC>=$baseqWC)?$baseqWC:$baseqCC;		
		my $c_cc=1-$baseqC;
		my $other = $baseqC/3;
		###type CC
		$cc = $nn + ($crick[2]+$watson[2])*log($c_cc) + ($watson[0]+$crick[0]+$crick[1]+$watson[3]+$crick[3])*log($other);
		if($watson[3]>0 || $crick[3]>0){#CG
			my $baseqG= ($baseqWG>=$baseqCG)?$baseqCG:$baseqWG;
			my $c_cg=(1-$baseqC)/2;
			$other=($baseqC)/2;
			$cg = $nn + ($crick[2]+$watson[3]+$watson[2]+$crick[3])*log($c_cg) + ($watson[0]+$crick[1])*log($other);
		}
	}
	if($wsq[3]>0 || $crq[3]>0 ){
		my $baseqG = ($baseqWG>=$baseqCG)?$baseqCG:$baseqWG;
		my $g_gg=1-$baseqG;
		my $other = $baseqG/3;			
		$gg = $nn + ($watson[3]+$crick[3])*log($g_gg) + ($watson[0]+$crick[1]+$watson[1]+$crick[2]+$watson[2])*log($other);
	}
	
	

	#P(D|g=Gj)					
	#sum(P(Gj)*P(D|g=Gj))
	my $fenmu=0;
	my %hash=map{($_,eval('$'."$_"))}('aa','tt','cc','gg','at','ac','ag','ct','gt','cg');
	foreach my $type(keys %hash){
		if($hash{$type}==0){
			delete($hash{$type});
		}
	}



	if($refbase eq "A"){
                $aa+=log(0.985);
                $tt+=log(0.000083);
                $cc+=log(0.000083);
                $gg+=log(0.00033);
                $at+=log(0.00017);
                $ac+=log(0.00017);
                $ag+=log(0.000667);
                $ct+=(log(2.78) - 8*log(10));
                $gt+=(log(1.1) - 7*log(10));
                $cg+=(log(1.1) - 7*log(10));    
        }    
        if($refbase eq "T"){
                $aa+=log(0.000083);
                $tt+=log(0.985);
                $cc+=log(0.00033);
                $gg+=log(0.000083);
                $at+=log(0.00017);
                $ac+=(log(1.1) - 7*log(10));
                $ag+=(log(2.78) - 8*log(10));
                $ct+=log(0.000667);
                $gt+=log(0.00017);
                $cg+=(log(1.1) - 7*log(10));
        }    
        if($refbase eq "C"){
                $aa+=log(0.000083);
                $tt+=log(0.00033);
                $cc+=log(0.985);
                $gg+=log(0.000083);
                $at+=(log(1.1) - 7*log(10));
                $ac+=log(0.00017);
                $ag+=(log(2.78) - 8*log(10));
                $ct+=log(0.000667);
                $gt+=(log(1.1) - 7*log(10));
                $cg+=log(0.00017);
        }    	
	if($refbase eq "G"){
                $aa+=log(0.00033);
                $tt+=log(0.000083);
                $cc+=log(0.000083);
                $gg+=log(0.9985);
                $at+=(log(1.1) - 7*log(10));
                $ac+=(log(1.1) - 7*log(10));
                $ag+=(log(6.67) - 4*log(10));
                $ct+=(log(2.78) - 8*log(10));
                $gt+=(log(1.67) - 4*log(10));
                $cg+=(log(1.67) - 4*log(10));
        }

	
    
	my %hash2=map{($_,eval('$'."$_"))} (keys %hash);	
	foreach my $type(keys %hash2){
               $fenmu+=2.7**$hash2{$type};
        }

    	my @sort = sort {$hash2{$b}<=>$hash2{$a}} keys %hash2;
	
	my $genotypemaybe;my $qual;
	my $prob=0;
	if(@sort==0){
		$genotypemaybe="NN";
		$qual=0;
	}else{
		$genotypemaybe=uc($sort[0]);
		my $first=2.7**$hash2{$sort[0]};
	#die "$first\n$fenmu\n";
		if(@sort>1){
			if($fenmu==0){
				$qual=1000;
			}else{
				$prob=1-$first/$fenmu;
				if($prob==0){

					$qual=1000;
				}else{
					$qual=-10*log($prob)/log(10);
				}
			}
		}elsif(@sort==1){
			#print STDERR $sort[0]."\n";
			if($sort[0] eq "aa"){
				my $hom=$watson[0];	
				$prob=1-1/(1+0.5**$hom);
			}
			elsif($sort[0] eq "tt"){
                                my $hom=$crick[1];     
                                $prob=1-1/(1+0.5**$hom);
                        }  	
			elsif($sort[0] eq "cc"){
				my $hom=$watson[2]+$crick[2];
				$prob=1-1/(1+0.5**$hom);
			}
			elsif($sort[0] eq 'tt'){
				my $hom=$watson[3]+$crick[3];
                                $prob=1-1/(1+0.5**$hom);
			}else{
				$prob=1;
			}

			if($prob==0){
				$qual=1000;	
			}else{
				$qual=-10*log($prob)/log(10);
			}
		}
	}
	
	
	$qual=int($qual);


        return "$genotypemaybe\t$qual";
	#return $genotypemaybe;
	#print "$sort[0]\t$hash{$sort[0]}\t$sort[1]\t$hash{$sort[1]}\n";
}

sub Factorial
{
	my $aa=shift;
	my $tt=shift;
	my $cc=shift;
	my $gg=shift;
	my $total=$aa+$tt+$cc+$gg;
	my ($naa,$ntt,$ncc,$ngg,$ntotal);
	if($aa<=1){
		$naa=0;	
	}else{
		foreach my $xx(1..$aa){
			$naa+=log($xx);
		}
	}
	if($tt<=1){
                $ntt=0; 
        }else{
                foreach my $xx(1..$tt){
                        $ntt+=log($xx);
                }   
        }   
	if($cc<=1){
                $ncc=0; 
        }else{
                foreach my $xx(1..$cc){
                        $ncc+=log($xx);
                }   
        }   
	if($gg<=1){
                $ngg=0; 
        }else{
                foreach my $xx(1..$gg){
                        $ngg+=log($xx);
                }   
        }   	
	if($total<=1){
                $ntotal=0; 
        }else{
                foreach my $xx(1..$total){
                        $ntotal+=log($xx);
                }   
        }   

	my $nn=$ntotal-$naa-$ncc-$ntt-$ngg;
	return $nn;	
}



