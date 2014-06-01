#!/usr/bin/perl -w
#############################################################################
# PROGRAM
#     sitediff
#
# SYNOPSIS
#     Used to diff website files between a local server and remote server
#
# USAGE
#     sitediff OPTIONS
#
# OPTIONS
#     -d [dirname]    Diff all files in a directory (not recursive)
#     -f [filename]   Diff a single file in current working directory
#     -h              Usage information
#     -i [ip address] FTP ip address
#     -p [password]   FTP site password
#     -u [user name]  FTP site user name
#
# REQUIRED
#     Net::FTP
#
# AUTHOR
#     Steve Dickinson
#
# COMMENTS
#
# Development     : 12.27.10
# Initial Release : 12.27.10
#
# REVISIONS
#
# TO DO
#############################################################################
# GLOBAL VARIABLES / SETTINGS
# SET THE FOLLOWING VARIABLES TO CORRECT VALUES FOR THE FTP SITE
# NO OTHER SECTIONS NEED TO BE MODIFIED BY THE USER
#############################################################################
# REMOTE SERVER'S FTP CREDENTIALS
my  $opt_ip       	= "IP";
my  $opt_user     	= "LOGIN";
my  $opt_password  	= "PASSWORD";

# LOCAL SERVER'S ROOT DOCUMENT DIRECTORY
my $local_dir_root	= "/path/to/htdocs";

# LOCAL SERVER'S ROOT DIRECTORY FOR SITE
my  $local_dir		= $local_dir_root . "/mysite.com/html";

# REMOTE SERVER'S ROOT DIRECTORY FOR SITE
# Keep this blank if the ftp account dumps the user into site's root directory
# Otherwise make point it to the html root.
#my  $remote_dir_root   = "html/";  
my  $remote_dir_root    = "";  

#############################################################################
# INTERRUPT SIGNALS
#############################################################################
$SIG{'INT' } = 'clean_up'; $SIG{'HUP' } = 'clean_up';
$SIG{'QUIT'} = 'clean_up'; $SIG{'TRAP'} = 'clean_up';
$SIG{'ABRT'} = 'clean_up'; $SIG{'STOP'} = 'clean_up';
$SIG{'TSTP'} = 'clean_up';

#############################################################################
# INCLUDE
#############################################################################
use File::Basename;
use File::Find::Rule;
use File::Find::Rule::VCS();
use Net::FTP;
use Data::Dump qw(dump);
use Cwd;

use strict;

#############################################################################
# USAGE
#############################################################################
my $prog = basename($0,"");

sub usage {
    print "\nusage: $prog OPTIONS\n\n";
    print " Used to diff website files between a local server and remote server.\n\n";
    print " OPTIONS:\n";
    print "     -d [dirname]    Diff all files in a directory (not recursive)\n\n";
    print "     -f [filename]   Diff a single file in current working directory\n\n";
    print "     -h              Usage information\n\n";
    print "     -i [ip address] FTP ip address\n\n";
    print "     -p [password]   FTP site password\n\n";
    print "     -u [user name]  FTP site user name\n\n";

    exit 1;
}

#############################################################################
# MORE GLOBAL VARIABLES / SETTINGS
#############################################################################
my $VERSION         = "0.2";
my $DEBUG           = 0;

my $pwd	    		= getcwd();
my $remote_dir_pwd	= $local_dir_root;
$remote_dir_pwd		=~s /$local_dir//g;
if ($remote_dir_root ne "") {
    $remote_dir_pwd	= $remote_dir_root . "/" . $remote_dir_pwd;
}

my $arg_file 		= "false";
my $arg_dir 		= "false";
my $arg_ip 			= "false";
my $arg_password	= "false";
my $arg_user 		= "false";
my $arg_help 		= "false";

my $check_dir		= "false";
my $check_file		= "false";

my $opt;
my ($opt_dir, $opt_file, $pwd_dir, $last_dir, $last_file, $cwd, $ftp, $node, $arg, @diff, @final_dirs, @final_files, $tmpfile);
my $partial_dir = 0;
my $partial_file = 0;
my $node_count = 0;

#############################################################################
# PARSE OPTIONS
#############################################################################
if ($#ARGV == -1) {
    usage();
}
sub find_node {
	
}

for (my $argc = 0; $argc <= $#ARGV; $argc++) { 
    if ($ARGV[$argc]) { 
        $opt = $ARGV[$argc]; 
        if ($opt !~ /^-[a-z]/) {
            usage();
        }
    	$opt =~ s/--//; # Get rid of 2 dashes 
		$opt =~ s/-//; # Get rid of 1 dash 
		$opt = substr($opt,0,1); # cut the first char 
    } 

    if ($opt eq 'd') { 
        $arg_dir = "true"; 
        $opt_dir = $ARGV[++$argc]; 
		if ($opt_dir !~ /^$local_dir/) { #otherwise we got the full path
			if ($opt_dir =~ /\/([^\/]+)$/) {
				$partial_dir = 1; # given a partial dir
				$last_dir = $1; # get the last dir name
			} else {
				$last_dir = $opt_dir;
			}
			$tmpfile = "/tmp/$last_dir" . ".$$";
			my @dirs = File::Find::Rule
					->mindepth(0)
					->directory()
					->ignore_hg
					->name( $last_dir )
					->in( $local_dir );
			foreach my $dir (@dirs) {
				if ($partial_dir == 1 && $dir =~ /$opt_dir/) {
					push (@final_dirs, $dir);
				} elsif ($partial_dir == 0) {
					push (@final_dirs, $dir);
				}
			}
			if (length(@final_dirs > 1)) {
				error("$prog: Ambigous directory paths for '$opt_dir' found. Use the full path instead."); 
			}	
			if (!defined($final_dirs[0])) {
				error("$prog: Path '$opt_dir' not found. Use the full path instead."); 
			}
			$opt_dir = $final_dirs[0];
		}
        $check_dir = check_node($opt_dir); 
		if ($check_dir eq "false") {
			error("$prog: Path '$opt_dir' not found."); 
		}
    } elsif ($opt eq 'f') { 
        $arg_file = "true"; 
        $opt_file = $ARGV[++$argc]; 
        $opt_file =~s /\/$//;
		if ($opt_file !~ /^$local_dir/) { #otherwise we got the full path
			if ($opt_file =~ /\/([^\/]+)$/) {
				$partial_file = 1; # given a partial dir
				$last_file = $1; # get the last dir name
			} else {
				$last_file = $opt_file;
			}
			$tmpfile = "/tmp/$last_file" . ".$$";
			my @files = File::Find::Rule
					->mindepth(0)
					->file()
					->ignore_hg
					->name( $last_file )
					->in( $local_dir );
			foreach my $file (@files) {
				if ($partial_file == 1 && $file =~ /$opt_file/) {
					push (@final_files, $file);
				} elsif ($partial_file == 0) {
					push (@final_files, $file);
				}
			}
			if (length(@final_files > 1)) {
				error("$prog: Ambigous directory paths for '$opt_file' found. Use the full path instead."); 
			}	
			if (!defined($final_files[0])) {
				error("$prog: Path '$opt_file' not found. Use the full path instead."); 
			}
			$opt_file = $final_files[0];
		}
        $check_file = check_node($opt_file); 
		if ($check_file eq "false") {
			error("$prog: Path '$opt_file' not found."); 
		}
		$opt_dir = $local_dir;
		$opt_file =~s /$local_dir//;
		$opt_file =~s /^\///;
		$opt_file = $remote_dir_root . $opt_file;
    } elsif ($opt eq 'h') {
        $arg_help = "true";
        usage();
        exit 1;
    } elsif ($opt eq 'i') {
        $arg_ip = "true";
        $opt_ip = $ARGV[++$argc];
    } elsif ($opt eq 'p') {
        $arg_password = "true";
        $opt_password = $ARGV[++$argc];
    } elsif ($opt eq 'u') {
        $arg_user = "true";
        $opt_user = $ARGV[++$argc];
    } else { 
        usage(); 
        exit 1; 
    } 
}

#############################################################################
# CHECK NODE
#############################################################################
sub check_node {
    my $node_name = shift;
    my $status = "false";
    
    if ($arg_dir eq "true" && -d "$node_name") {
        $status = "true";	    	
    }
    
    if ($arg_file eq "true" && -e "$node_name") {
        $status = "true";	    	
    }
    
    return ($status);
}

#############################################################################
# MAIN
#############################################################################
main();
sub main {
    print "============\n";
    print "sitediff $VERSION\n";
    print "============\n";
	if (!defined($opt_dir)) {
		$remote_dir_pwd = $remote_dir_root;
	} else {
		$remote_dir_pwd = $remote_dir_root . $opt_dir;
	}
	$remote_dir_pwd =~s /$local_dir_root//;
	$remote_dir_pwd =~s /^\///;

    $ftp = Net::FTP->new($opt_ip) or die ("ERROR: Could not connect to $opt_ip!");
    $ftp->login($opt_user,$opt_password) or die ("ERROR: ftp site login failure!");
    $cwd = $ftp->cwd("$remote_dir_pwd");
    if ($cwd eq "") {
        print "ERROR: $remote_dir_pwd does not exist on remote server or\nyou do not have permissions to this directory!\n";
        $ftp->quit;
        exit;
    }
    $ftp->ascii;
    if ($arg_dir eq "true") {
		$opt_dir =~s /\/$//;
        opendir (DIR, "$opt_dir") or die ("Could not open $opt_dir!");
        while ($node = readdir(DIR)) {
            chomp ($node);
            if (-d "$opt_dir/$node") {next;}
			$node_count++;
            print "\n########################################################################################################\n";
            print "# $opt_dir/$node\n";
            print "########################################################################################################\n";
            diff_file($opt_dir, $node);
        }   
        closedir(DIR);
		if ($node_count == 0) {
			print "No files found.\n";
		}
    } elsif ($arg_file eq "true") {
        print "\n########################################################################################################\n";
		print "# $opt_dir/$opt_file\n";
        print "########################################################################################################\n";
        diff_file($opt_dir, $opt_file);
    } else {
        error("ERROR: Unknown option given!");
    }

    $ftp->quit;
    exit;
}

#############################################################################
# DIFF FILE FUNCTION
#############################################################################
sub diff_file {
    undef @diff;
    my ($opt_dir, $node) = @_; 
	if (!defined($tmpfile)) {
    	$tmpfile = "/tmp/" . "$$"; 
	}
    my $get = $ftp->get($node, $tmpfile);
    if (! $get) {
        print "ERROR: $node does not exist on remote server!\n";
        return;   
    }   

	my $path;
	if ($opt_dir eq "") {
		$path = $node;
	} else {
		$path = "$opt_dir/$node";
	}
    #@diff = `diff $path $node.$$`;
    @diff = `diff $path $tmpfile`;
    if (!defined($diff[0])) {
        print "Files are identical.\n";
    } else {   
    	print "diff < local server, > remote server\n";
	    foreach (@diff) {
    	    print $_; 
    	}   
	}
    unlink("$tmpfile");
}

#############################################################################
# ERROR
#############################################################################
sub error {
    my $msg = shift;
    print "\n$msg\n\n";
    exit 1;
}

#############################################################################
# CLEAN UP
#############################################################################
sub clean_up {
    exit;
}
