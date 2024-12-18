<?php

// This file is part of Moodle - http://moodle.org/
//
// Moodle is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Moodle is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Moodle.  If not, see <http://www.gnu.org/licenses/>.

/**
 * This file formats the data from the run into a format that can be used by the performance test system more widely.
 *
 * @copyright Andrew Lyons <andrew@nicols.co.uk>
 * @license http://www.gnu.org/copyleft/gpl.html GNU Public License
 */

// Removing the script name.
array_shift($argv);

foreach ($argv as $inputfile) {
    $filename = pathinfo($inputfile, PATHINFO_FILENAME);
    $filepath = pathinfo($inputfile, PATHINFO_DIRNAME);
    if (!str_ends_with($inputfile, '.php')) {
        echo 'Error: You need to specify the runs filenames without their .php suffix.' . PHP_EOL;
        exit(1);
    }

    if (!file_exists($inputfile)) {
        echo "Error: The file $inputfile does not exist." . PHP_EOL;
        exit(1);
    }

    $data = get_normalised_dataset($inputfile);
    $outputfile = "{$filename}.json";
    file_put_contents("{$filepath}/{$filename}.json", json_encode($data, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES) . "\n");

    echo "Converted file {$inputfile} to {$outputfile}" . PHP_EOL;
}

function get_normalised_dataset($datapath) {
    require_once($datapath);
    $runinfovars = [
        'host',
        'sitepath',
        'group',
        'rundesc',
        'users',
        'loopcount',
        'rampup',
        'throughput',
        'size',
        'baseversion',
        'siteversion',
        'sitebranch',
        'sitecommit',
    ];

    foreach ($runinfovars as $var) {
        // In case runs don't have all vars defined.
        if (empty($$var)) {
            $$var = 'Unknown';
        }
    }

    $filename = pathinfo($datapath, PATHINFO_FILENAME);

    return (object) [
        'filename' => "{$filename}.json",
        'host' => $host,
        'sitepath' => $sitepath,
        'group' => $group,
        'rundesc' => $rundesc,
        'users' => $users,
        'loopcount' => $loopcount,
        'rampup' => $rampup,
        'throughput' => $throughput,
        'size' => $size,
        'baseversion' => $baseversion,
        'siteversion' => $siteversion,
        'sitebranch' => $sitebranch,
        'sitecommit' => $sitecommit,
        'results' => $results,
    ];
}
