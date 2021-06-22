import 'dart:io';

import 'package:csv/csv.dart';
import 'package:tabulate/tabulate.dart';

Map<int, Set<Player>> pickToPlayers = {};
Map<Season, double> seasonToLebronWA = {};
Map<Season, double> seasonToRaptorWA = {};

double lebronWeight = 0.0;
double raptorWeight = 1.0;

/// This analysis is my work mathematically, but I owe all of my data to
/// references. My WAR (wins-above-replacement) measurement comes from
/// FiveThirtyEight's Raptor historical data, and my draft pick data comes from
/// Basketball Reference.
///
/// Additionally, I used two external libraries in this Dart file: a csv parsing
/// library and a table formulation library. The authors of those libraries
/// retain the right to their intellectual property, which I utilize here as
/// per the terms of their licenses.

void main(List<String> arguments) {
  var startYear = 2002;
  var finalYear = 2016;
  var firstNYears = 5;

  var year = startYear;

  var raptorCsv = File('stats/RAPTOR/raptor.csv');
  var listRowsRaptor = CsvToListConverter(eol: '\n').convert(raptorCsv.readAsStringSync());
  for (var i = 1; i < listRowsRaptor.length; i++) {
    var row = listRowsRaptor[i];
    var season = Season(row[0] as String, (row[2] as num).toInt() - 1);
    seasonToRaptorWA[season] = (row[9] as num).toDouble();
  }

  while (year <= finalYear) {
    var draftCsv = File('stats/draft/$year.csv');
    var listRows = CsvToListConverter(eol: '\n').convert(draftCsv.readAsStringSync());
    var draftSpot = 1;
    while (draftSpot < listRows.length) {
      var playerRow = listRows[draftSpot];
      if (playerRow[0] == 'pk') continue;
      var player = Player(playerRow[2] as String, {});
      var draftSpotPlayers = pickToPlayers[draftSpot];
      if (draftSpotPlayers == null) {
        pickToPlayers[draftSpot] = {player};
      } else {
        pickToPlayers[draftSpot].add(player);
      }
      for (var i = year; i < year + firstNYears; i++) {
        var rwa = seasonToRaptorWA[Season(player.name, i)];
        rwa = rwa ?? 0;

        player.yearToWinsAdded[i] = rwa * raptorWeight;
      }

      draftSpot++;
    }
    year++;
  }


  double standard;
  double minWAR = 100;
  for (var spot in pickToPlayers.keys) {
    var playersAtSpot = pickToPlayers[spot];
    var totalWAR = 0.0;

    for (var player in playersAtSpot) {
      var valueList = player.yearToWinsAdded.values.toList();
      for (var i = 0; i < firstNYears; i++) {
        totalWAR += valueList[i];
      }
    }

    double output;
    if (standard == null) {
      output = 100;
      standard = totalWAR;
    } else {
      output = totalWAR/standard*100;
    }
    if (output < minWAR) {
      minWAR = output;
    }
  }

  minWAR = minWAR > 0 ? minWAR : -minWAR;
  standard += minWAR;


  var table = <List<String>>[];
  for (var spot in pickToPlayers.keys) {
    var playersAtSpot = pickToPlayers[spot];
    var totalWAR = 0.0;

    for (var player in playersAtSpot) {
      var valueList = player.yearToWinsAdded.values.toList();
      for (var i = 0; i < firstNYears; i++) {
        totalWAR += valueList[i];
      }
    }

    double output;
    if (spot == 1) {
      output = 100;
    } else {
      output = (totalWAR)/standard*100 + minWAR;
    }
    table.add(['$spot', formatDouble(output)]);
  }


  var bracketTable = <List<String>>[];
  double standard2;
  var cumulatedRelative = 0.0;
  var cumulatedWAR = 0.0;

  for (var spot in pickToPlayers.keys) {
    var playersAtSpot = pickToPlayers[spot];
    var totalWAR = 0.0;

    for (var player in playersAtSpot) {
      var valueList = player.yearToWinsAdded.values.toList();
      for (var i = 0; i < firstNYears; i++) {
        totalWAR += valueList[i];
      }
    }

    double output;
    if (standard2 == null) {
      standard2 = totalWAR;
      bracketTable.add(['1', '100', formatDouble(totalWAR)]);
    } else {
      output = totalWAR/standard2*100;
      cumulatedRelative += output;
      cumulatedWAR += totalWAR;
    }


    if (spot != 5 && spot % 5 == 0) {
      cumulatedRelative /= 5;
      cumulatedWAR /= 5;
      bracketTable.add(['${spot-4}-$spot', formatDouble(cumulatedRelative), formatDouble(cumulatedWAR)]);
      cumulatedRelative = 0;
    } else if (spot == 5) {
      cumulatedRelative /= 4;
      cumulatedWAR /= 4;
      bracketTable.add(['2-5', formatDouble(cumulatedRelative), formatDouble(cumulatedWAR)]);
      cumulatedRelative = 0;
    }
  }
  // Output spot values to console.
  print(tabulate(table, ['Draft Position', 'Value (0-100)']));

  // Output spot values to CSV.
  table.insert(0, ['Draft Position', 'Value (0-100)']);
  var csv = table.map((e) => e.join(',')).join('\n');
  var outputFile = File('output/values.csv');
  if (!outputFile.existsSync()) {
    outputFile.createSync();
  }
  outputFile.writeAsStringSync(csv);

  // Output range averages to console.
  print(tabulate(bracketTable, ['Draft Position(s)', 'Avg. Value (0-100)', 'Avg. WAR after $firstNYears yrs.']));
}

String formatDouble (double base) {
  return '$base'.length > 7 ? '$base'.substring(0, 7) : '$base';
}

class Player {
  String name;
  Map<int, double> yearToWinsAdded;

  Player(this.name, this.yearToWinsAdded);

  @override
  bool operator ==(Object other) {
    return name == name;
  }

  @override
  String toString() => name;
}

class Season {
  String playerName;
  int seasonYear; // first year (e.g. 2018 for 2018-19 season)

  Season(this.playerName, this.seasonYear);

  @override
  bool operator ==(covariant Season other) {
    return playerName == other.playerName && seasonYear == other.seasonYear;
  }

  @override
  int get hashCode => playerName.hashCode ^ seasonYear.hashCode;
}