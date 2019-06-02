#!/usr/bin/perl -w -I.
# # vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop
#

use strict;

use Parse::BBCode;
use Data::Dumper;

my $bbc = Parse::BBCode->new({
  attribute_quote => q/'"/,
  tags => {
    Parse::BBCode::HTML->defaults,
    center => '<div style="text-align: center">%s</div>',
    'indent' => '<div style="margin-left: 20px">%s</div>',
    'url'   => 'url:<a href="%{link}A" rel="nofollow">%s</a>',
    'color' => {
      parse => 1,
      code => sub {
        my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
        #printf STDERR "COLOR tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
        if ($attr =~ /^(?<rgb>rgb\([0-9]+, *[0-9]+, *[0-9]+\))$/) {
          #printf STDERR "Found COLOR with %s\n", $attr;
          return sprintf("<span style=\"color: %s\">%s</span>", $+{'rgb'}, ${$content});
        }
      },
      close => 0,
      #class => 'block'
    },
    'attach' => {
      parse => 1,
      code => sub {
        my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
        #printf STDERR "ATTACH tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
        if (${$content} =~ /^(?<alt>[0-9]+)$/) {
          #printf STDERR "Found ATTACH with %s\n", ${$content};
          return sprintf("<img src=\"https://forums.frontier.co.uk/attachments/%s\" alt=\"%s\">", ${$content}, ${$content});
        }
      },
      close => 0,
    },
    'table' => '<table style="width: 100%"><tbody>%s</tbody></table>',
    'tr' => '<tr>%s</tr>',
    'td' => '<td>%s</td>',
    'media' => {
      parse => 1,
      code => sub {
        my ($parser, $attr, $content, $attribute_fallback, $tag) = @_;
        #printf STDERR "MEDIA tag:\n\tcontent: '%s'\n\tattr: %s\n\ttag: '%s'\n", Dumper($content), Dumper($attr), Dumper($tag);
        if ($attr =~ 'youtube') {
          return sprintf("<div class=\"bbMediaWrapper\"><div class=\"bbMediaWrapper-inner\"><iframe src=\"https://www.youtube.com/embed/%s?wmode=opaque\&start=0\" allowfullscreen=\"true\"></iframe></div></div>", ${$content});
        }
      },
      close => 0,
    },
  },
#  escapes => {
#    rgb => sub {
#      my $color = $_[2];
#      ($color =~ m/^(?<rgb>=rgb\([0-9]+, *[0-9]+, *[0-9]+\))$/) ? $color : 'inherit';
#    }
#  }
});

my $incode = <<"EOBB";
[COLOR=rgb(243, 121, 52)]Beginner's Zone[/COLOR]
[CENTER][ATTACH type="full" alt="127332"]127332[/ATTACH][/CENTER]
[INDENT][COLOR=rgb(243, 121, 52)]Advanced Docking Computer[/COLOR][/INDENT]
[INDENT=3]no longer includes spurious ammo stats for energy weapons[/INDENT]
[URL='https://www.twitch.tv/deejayknight']Twitch[/URL]
[MEDIA=youtube]64EOTqrJOR0[/MEDIA]
[TABLE] [TR] [TD]Distance between Sol and IC 2391 Sector FL-X B1-7[/TD] [TD]619ly[/TD] [/TR] [/TABLE]
EOBB
printf STDERR "Original:\n%s\n\n", $incode;

my $munged = $incode;
$munged =~ s/\[COLOR=(?<rgb>rgb\([^\)]+\))\]/\[COLOR='$+{'rgb'}'\]/gm;
$munged =~ s/\[ATTACH (?<type>type="full" )(?<alt>alt="[0-9]+")\]/\[ATTACH $+{'alt'}\]/gm;
printf STDERR "Munged:\n%s\n\n", $munged;

my $parsed = $bbc->render($munged);
printf STDERR "Parsed:\n%s\n\n", $parsed;

###########################################################################
#
# NOTES:
#   Only allowed one attribute per BBCode tag
#     [ATTACH type="full" alt="127332"] <--- not parsed
#     [ATTACH alt="127332"]1            <--- parsed
#
#   MUST have single or double quotes around attribute
#     [COLOR=rgb(243, 121, 52)]         <--- not parsed
