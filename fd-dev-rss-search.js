/* vim: textwidth=0 wrapmargin=0 shiftwidth=2 tabstop=2 expandtab softtabstop
 */

var performSearch_inprogress = false;

function performSearch(ev) {
  ev.preventDefault();

  if (performSearch_inprogress) {
    $(".results#status").text("");
    $(".results#status").append("<p>Search is <strong>already</strong> in progress, please <em>be patient</em>!</p>");
    return;
  }

  clearResultsOutput();

  if (!$('#search_text').val()) {
    $(".results#status").text("");
    $(".results#status").append("<p>You need to enter some search terms!</p>");

    return false;
  }

  // If there are no ampersands or pipes or exclamation marks, assume someone
  // wants a simple "all these words" search and insert the necessary & characters.
  var q = $('#search_text').val();
  if (q.search('[\&\|\!]') == -1) {
    var terms = q.split(' ');
    q = terms.join(' & ');

  }
  search_query = {
    search_text: q
  };

  $.ajax({
    url: "search.pl",
    type: "GET",
    data: search_query,
    dataType: "json",
    async: true,
    success: onSearchResults,
    error: onSearchError,
    timeout: 20000
  });

  performSearch_inprogress = true;

  return false;
}

function onSearchError(jqXHR, textStatus, errorThrown) {
  console.log('onSearchError: %o, %o, %o', jqXHR, textStatus, errorThrown);
  performSearch_inprogress = false;
  $(".results#status").text("");
  $(".results#status").append("<p>Error performing search: " + textStatus + "(" + errorThrown.message + ")</p>");
}

function onSearchResults(data) {
  console.log('onSearchResults: data = %o', data);
  performSearch_inprogress = false;
  $(".results#status").text("");

  if (data.status != 'ok') {
    $(".results#status").append("<p>Search failed: " + data.reason + "</p>");
    return;
  }

  displaySearchResults(data);
}

function displaySearchResults(data) {
  console.log('displaySearchResults: For array %o', data.results);
  var after;

  for (r = 0; r < data.results.length ; r++) {
    var new_r = $("#result_X.result_row").clone();
    new_r.attr("id", 'result_' + r);
    console.log('displaySearchResults: cloned search result %o', new_r);
    if (r == 0) {
      after = $("#results_output").find("#result_X");
    }
    new_r.find(".results_info_item.result_rank").text(data.results[r].rank);
    new_r.find(".results_info_item.result_datestamp").text(data.results[r].datestamp);
    // <a href="URL">ThreadTitle</a> (Forum)
    var new_r_url = new_r.find(".results_info_item.result_thread").html(
      $('<a>', {
        href: 'https://forums.frontier.co.uk/' + data.results[r].url,
        text: data.results[r].threadtitle
      })
    );
    new_r_url.append(' (' + data.results[r].forum + ')');
    new_r.find(".results_info_item.result_who").text(data.results[r].who);
    new_r.find(".results_info_item.result_precis").text(data.results[r].precis);
    new_r.insertAfter(after);
    after = new_r;
  }
}

function clearResultsOutput() {
  $(".results#status").text("");
  $(".result_row").not("#result_X").remove();
}

$(function() {
  $("#form_precis_search").submit(performSearch);
});
