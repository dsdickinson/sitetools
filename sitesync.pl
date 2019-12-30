#!/usr/bin/perl -w
#############################################################################
# PROGRAM
#     sitesync
#
# SYNOPSIS
#     Used to copy over updated website files from the
#     test server to the production server
#
# USAGE
#     sitesync  [-a] [-d <dirname>] [-f <filename>] [-h] [-i <ip address>] [-m] [-n] [-p <password>] [-u <user name>] [-z]
#
# OPTIONS
#    -a              Transfer entire site to live server
#
#    -d [dirname]    Transfer an entire directory to live server
#
#    -f [filename]   Transfer a single file to live server
#
#    -h              Usage information
#
#    -i [ip address] FTP site ip address
#
#    -m              Inform of file overwrite
#
#    -n              No prompting before transfering files
#
#    -p [password]   FTP site password
#
#    -u [username]   FTP site user name
#
#    -z              Transfer hidden files
#
#
# REQUIRED
#     Net::FTP::File
#
# AUTHOR
#     Steve Dickinson
#
# COMMENTS
#
# Development     : 12.22.07
# Initial Release : 12.27.07
#
# REVISIONS
#
#############################################################################
# GLOBAL VARIABLES / SETTINGS
# SET THE FOLLOWING VARIABLES TO CORRECT VALUES FOR THE FTP SITE
# NO OTHER SECTIONS NEED TO BE MODIFIED BY THE USER
#############################################################################
# REMOTE SERVER'S FTP CREDENTIALS
my  $opt_ip             = "IP";
my  $opt_user           = "LOGIN";
my  $opt_password       = "PASSWORD";

# LOCAL SERVER'S ROOT DOCUMENT DIRECTORY
my $local_dir_root      = "/path/to/htdocs";

# LOCAL SERVER'S ROOT DIRECTORY FOR SITE
my  $local_dir          = $local_dir_root . "/mysite.com/html";

# REMOTE SERVER'S ROOT DIRECTORY FOR SITE
# Keep this blank if the ftp account dumps the user into site's root directory
# Otherwise make point it to the html root.
#my  $remote_dir_root    = "html/";  
my  $remote_dir_root     = ""; 

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
use Net::FTP::File;
use Data::Dump qw(dump);
use Cwd;

use strict;

#############################################################################
# USAGE
#############################################################################
my $prog = basename($0,"");

sub usage {
    print "\nusage: $prog OPTIONS\n\n";
    print "   Used to copy over updated website files from a test server to a production server.\n\n";
    print "     -a              Transfer entire site to live server\n\n";
    print "     -d [dirname]    Transfer an entire directory to live server\n\n";
    print "     -f [filename]   Transfer a single file to live server\n\n";
    print "     -h              Usage information\n\n";
    print "     -i [ip address] FTP site ip address\n\n";
    print "     -m              Inform of overwrite\n\n";
    print "     -n              No prompting before transfering files\n\n";
    print "     -p [password]   FTP site password\n\n";
    print "     -t [MMDDYYYY]   Transfer files that are older than the specified date.\n\n";
    print "     -u [user name]  FTP site user name\n\n";
    print "     -z              Transfer hidden files\n\n";
   
    exit 1;
}

#############################################################################
# VARS
#############################################################################
my $DEBUG			= 0;

our $pwd	    	= getcwd();

my  %BINARY = ( 
		"zip"   => 1,
		"Z",    => 1,
		"tgz"   => 1,
		"gz"    => 1,
		"tar"   => 1,
		"bzip2" => 1,
		"jpeg"  => 1,  
		"jpg"   => 1,
		"gif"   => 1,
		"tiff"  => 1,
		"png"   => 1,
		"bmp"   => 1,
		"ppt"   => 1,
		"xls"   => 1,
		"exe"   => 1
);

my $arg_all 		= "false";
my $arg_file 		= "false";
my $arg_dir 		= "false";
my $arg_help 		= "false";
my $arg_ip			= "false";
my $arg_password	= "false";
my $arg_user		= "false";
my $arg_inform		= "false";
my $arg_noprompt	= "false";
my $arg_hidden  	= "false";
my $arg_date        = "false";

my $check_dir		= "false";
my $check_file		= "false";

my $opt;
my ($opt_dir, $opt_file, $pwd_dir, $last_dir, $last_file, @final_dirs, @final_files, $tmpfile);
my $partial_dir 	= 0;
my $partial_file 	= 0;
my $node_count 		= 0;

my @ftp_files;
my %ftp_files_sizes;
my $ftp;
my $ftp_type;

#############################################################################
# PARSE OPTIONS
#############################################################################
if ($#ARGV == -1) {
    usage();
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

    if ($opt eq 'a') { 
        $arg_all = "true"; 
    } elsif ($opt eq 'd') { 
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
		if (!$check_dir) {
			error("$prog: Path '$opt_dir' not found. Use the full path instead."); 
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
#		$opt_file = $remote_dir_root . $opt_file;
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
    } elsif ($opt eq 'm') { 
        $arg_inform = "true"; 	
    } elsif ($opt eq 'n') { 
        $arg_noprompt = "true"; 	
    } elsif ($opt eq 't') { 
        $arg_date = "true"; 	
    } elsif ($opt eq 'z') { 
        $arg_hidden = "true"; 		
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
    @ftp_files = get_files();
    ftp_files(\@ftp_files);    
    exit;
}

#----------------------------------------------------------------------------
# GET FILES
#----------------------------------------------------------------------------
sub get_files {
    my $prompt;
    my (@files, $single_file);
    my $prompt_choice = "";
	
	my $path_dir;
	if (defined($opt_dir)) {
		if ($opt_dir =~ /^$local_dir/) {
			$path_dir = "";
		} else {
			$path_dir = $local_dir . "/";
		}
	}

	if (defined($opt_file)) {
		if ($opt_file =~ /^$local_dir/) {
			$path_dir = "";
		} else {
			$path_dir = $local_dir . "/";
		}
	}

    if ($arg_noprompt eq "true") {
		$prompt_choice = "y";
    } else {
		if ($arg_all eq "true") {
			$prompt  = "Directory: '$local_dir'\n";
		} elsif ($check_dir eq "true" && $check_file eq "false") {
			$prompt  = "Directory: '${path_dir}${opt_dir}'\n";
		} elsif ($check_file eq "true" && $check_dir eq "false") {
			$prompt .= "     File: '${path_dir}${opt_file}'\n";
		} elsif ($check_dir eq "true" && $check_file eq "true") {
			$prompt  = "Directory: '${path_dir}${opt_dir}'\n";
			$prompt .= "     File: '${path_dir}${opt_file}'\n";
		} else {
			error("$prog: Directory or file not found!");
		}

        $prompt .= "\nTransfer the above inode(s) to live server?";

		until ($prompt_choice =~ /^[YyNnQq]$/) {
			print "\n$prompt (y/n/q): ";
			$prompt_choice = <STDIN>;
			chomp ($prompt_choice);
		}	    
	}
    
    if ($prompt_choice =~ /^[NnQq]$/) {
        print "\n$prog: Quit.\n\n";
        exit;
    } 

    if ($arg_all eq "true") {
	    @files = `find $local_dir -type f 2> /dev/null`;
    } 
    if ($arg_dir eq "true") {
	    @files = `find '${path_dir}${opt_dir}' -type f 2> /dev/null`;
    } 
    if ($arg_file eq "true") {
        $single_file = `find '${path_dir}${opt_file}' -type f 2> /dev/null`;
        push (@files, $single_file);
    }

	if (scalar(@files) == 0) {
		error("$prog: No files found to transfer!");
	}

    return @files;
}

sub get_files_sizes {
    my $files = shift;
    my (@stats, $size);
    my %file_sizes;
    
    foreach my $file (@$files) {
	    chomp ($file);
		@stats = stat($file);
	    $size = $stats[7];
	    $file_sizes{$file} = $size;
    }
    
    return %file_sizes;
}

sub get_files_diff {
    my @files = shift;
    my @stats;
    my %file_sizes;
    
    foreach my $file (@files) {
        chomp ($file);
        print "$file\n";
        @stats = stat($file);
        foreach my $stat (@stats) {
	    print "$stat\n";
        }
    }
    
    return %file_sizes;
}

sub ftp_files {
    my $files = shift;
    my ($dir_exists, $file_exists);
    
    if ($DEBUG == 0) {
        $ftp = Net::FTP->new($opt_ip, Passive => 1) or die ("$prog: Could not connect to ip address '$opt_ip'");
        $ftp->login($opt_user,$opt_password) or die ("$prog: FTP login failure");
        $dir_exists=$ftp->exists("$remote_dir_root");
        if ( ! $dir_exists ) {
            print "\n$prog: *** ERROR changing to '$remote_dir_root' on server!\n";
            print "             Check to make sure the directory exists on server.\n\n";
            exit;
        }
    }

    print "\n Beginning file transfer ...\n\n";

    foreach my $filename (@$files) {
        my $ow_choice = "";
        my ($to_dir, $to_file);
        my $check_transfer;
	
    	$filename =~s /\s+$//g;
	    $filename =~s /\n$//g;

	    # /usr/local/apache2/htdocs/site.com/dir/file.inc
	    # file, /usr/local/apache2/htdocs/site.com/dir/, .inc
	    my($base_filename, $directory, $suffix) = fileparse($filename, qr/\.[^.]*/);

	    # skip hidden files if we don't want them
	    if ($arg_hidden eq "false" && $base_filename eq "" && $suffix =~ /^\./) {
	        next;
	    }
	
	    # /usr/local/apache2/htdocs/site.com/dir/file.inc
	    $to_file = $filename;
	
	    # site.com/dir/file.inc
	    $to_file =~s /$local_dir\///;
	
	    # site/dir
	    $to_dir = $remote_dir_root . dirname($to_file);
		$to_dir =~s /\.$//;
		$to_file = $to_dir . "/" . $base_filename;
		if ($suffix ne "" ) {
			$to_file .= $suffix;
		}

        if ($arg_inform eq "true") {
            my $file_exists = $ftp->exists($to_file);	    
	    
	        if ($file_exists) {
	            until ($ow_choice =~ /^[YyNnQq]$/) {
		            print "Overwrite '$to_file' on server? (y/n/q): ";
		            $ow_choice = <STDIN>;
		            chomp ($ow_choice);
	            }
	            if ($ow_choice =~ /^[Qq]$/) {
		            $ftp->quit;
                    print "\n$prog: Quit.\n\n";
                    exit;
	            }
	            if ($ow_choice =~ /^[Nn]$/) {
	                next;
	            }
	        }  
        }
    
        if ($suffix ne "") {
            $suffix =~s /\.//;
            if ($BINARY{"$suffix"}) {
                if ($DEBUG == 0) {
                    $ftp->binary;
                } else {
                    $ftp_type = "binary";
                }
            } else {
                if ($DEBUG == 0) {
                    $ftp->ascii;
                } else {
                    $ftp_type = "ascii";
                }
            }
        } else {
            if ($DEBUG == 0) {
                $ftp->ascii;
            } else {
                $ftp_type = "ascii";
            }
        }
    
        if ($DEBUG == 0) {
	        $dir_exists=$ftp->exists("$to_dir");
	        if ( ! $dir_exists ) {
                $ftp->mkdir("$to_dir", 1);
	            $ftp->chmod(755, $to_dir);
	        }    
	
	        $check_transfer = $ftp->put($filename, $to_file);
	        if ($check_transfer ne $to_file) {
                print "\n$prog: *** ERROR transfer of '$to_file' to server failed!\n";
                print "             File not transfered.\n\n";
                exit;
            }
	        $ftp->chmod(644, $to_file);	
            print "o SUCCESSFULL transfer - $to_file\n";
        } else {
            print "DEBUG: ftp_type      = $ftp_type\n";
            print "DEBUG: filename      = $filename\n";
            print "DEBUG: directory     = $directory\n";
            print "DEBUG: base_filename = $base_filename\n";
            print "DEBUG: suffix        = $suffix\n";
            print "DEBUG: to_dir        = $to_dir\n";
            print "DEBUG: to_file       = $to_file\n\n";
        }
    }

    print "\n";

    if ($DEBUG == 0) {
        $ftp->quit;
    }
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
