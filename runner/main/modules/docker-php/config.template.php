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

unset($CFG);
global $CFG;
$CFG = new stdClass();

$CFG->dbtype    = getenv('DBTYPE');
$CFG->dblibrary = 'native';
$CFG->dbhost    = getenv('DBHOST');
$CFG->dbname    = getenv('DBNAME');
$CFG->dbuser    = getenv('DBUSER');
$CFG->dbpass    = getenv('DBPASS');
$CFG->prefix    = 'm_';
$CFG->dboptions = ['dbcollation' => getenv('DBCOLLATION')];

if ($replica = getenv('DBHOST_REPLICA')) {
    $CFG->dboptions['readonly'] = [
        'instance' => [
            [
                'dbhost' => $replica,
            ],
        ],
    ];
}

if (getenv('DBTYPE') === 'sqlsrv') {
    $CFG->dboptions['extrainfo'] = [
        // Disable Encryption for now on sqlsrv.
        // It is on by default from msodbcsql18.
        'Encrypt' => false,

        // Trust server certificates so self-signed certificates can be used.
        'TrustServerCertificate' => true,
    ];
}

// Skip language upgrade during the on-sync period.
$CFG->skiplangupgrade = false;

$CFG->wwwroot   = getenv('MOODLE_WWWROOT') ?: 'http://host.name';
$CFG->dataroot  = '/var/www/moodledata';
$CFG->admin     = 'admin';
$CFG->directorypermissions = 0777;

// Debug options - possible to be controlled by flag in future..
$CFG->debug = (E_ALL | E_STRICT); // DEBUG_DEVELOPER
$CFG->debugdisplay = 1;
$CFG->debugstringids = 1; // Add strings=1 to url to get string ids.
$CFG->perfdebug = 15;
$CFG->debugpageinfo = 1;
$CFG->allowthemechangeonurl = 1;
$CFG->passwordpolicy = 0;

$CFG->phpunit_dataroot  = '/var/www/phpunitdata';
$CFG->phpunit_prefix = 't_';

// Set the generated users password to avoid the default non-loggeable one.
$CFG->tool_generator_users_password = 'toolgeneratorpassword';

if (\moodlehq_ci_runner::job_type_matches('behat')) {
    // Configure behat.
    \moodlehq_ci_runner::set_behat_configuration(
        getenv('WEBSERVER'),
        getenv('BROWSER'),
        getenv('BEHAT_PARALLEL'),
        !empty(getenv('BEHAT_TIMING_FILENAME')),
        getenv('BEHAT_INCREASE_TIMEOUT')
    );
}

// Apply custom configuration settings.
if ($config = getenv('MOODLE_CONFIG')) {
    \moodlehq_ci_runner::apply_config_settings($config);
}

// Enable tests needing language install/upgrade
// only if we have language upgrades enabled (aka,
// when we aren't skipping them).
if (empty($CFG->skiplangupgrade)) {
    define('TOOL_LANGIMPORT_REMOTE_TESTS', true);
}

define('PHPUNIT_LONGTEST', true);

define('PHPUNIT_PATH_TO_SASSC', '/usr/bin/sassc');

define('TEST_LDAPLIB_HOST_URL', getenv('LDAPTESTURL'));
define('TEST_LDAPLIB_BIND_DN', 'cn=admin,dc=openstack,dc=org');
define('TEST_LDAPLIB_BIND_PW', 'password');
define('TEST_LDAPLIB_DOMAIN', 'ou=Users,dc=openstack,dc=org');

define('TEST_AUTH_LDAP_HOST_URL', getenv('LDAPTESTURL'));
define('TEST_AUTH_LDAP_BIND_DN', 'cn=admin,dc=openstack,dc=org');
define('TEST_AUTH_LDAP_BIND_PW', 'password');
define('TEST_AUTH_LDAP_DOMAIN', 'ou=Users,dc=openstack,dc=org');

define('TEST_ENROL_LDAP_HOST_URL', getenv('LDAPTESTURL'));
define('TEST_ENROL_LDAP_BIND_DN', 'cn=admin,dc=openstack,dc=org');
define('TEST_ENROL_LDAP_BIND_PW', 'password');
define('TEST_ENROL_LDAP_DOMAIN', 'ou=Users,dc=openstack,dc=org');

if ($solrtestname = getenv('SOLRTESTNAME')) {
    define('TEST_SEARCH_SOLR_HOSTNAME', $solrtestname);
    define('TEST_SEARCH_SOLR_INDEXNAME', 'test');
    define('TEST_SEARCH_SOLR_PORT', 8983);
}

if ($redistestname = getenv('REDISTESTNAME')) {
    define('TEST_SESSION_REDIS_HOST', $redistestname);
    define('TEST_CACHESTORE_REDIS_TESTSERVERS', $redistestname);
}

if ($memcached1testurl = getenv('MEMCACHED1TESTURL')) {
    if ($memcached2testurl = getenv('MEMCACHED2TESTURL')) {
        define('TEST_CACHESTORE_MEMCACHED_TESTSERVERS', $memcached1testurl. "\n" . $memcached2testurl);
    } else {
        define('TEST_CACHESTORE_MEMCACHED_TESTSERVERS', $memcached1testurl);
    }
}

if ($mongodbtesturl = getenv('MONGODBTESTURL')) {
    define('TEST_CACHESTORE_MONGODB_TESTSERVER', $mongodbtesturl);
}

if (!empty(getenv('EXTTESTURL'))) {
    define('TEST_EXTERNAL_FILES_HTTP_URL', getenv('EXTTESTURL'));
    define('TEST_EXTERNAL_FILES_HTTPS_URL', getenv('EXTTESTURL'));
}

if (property_exists($CFG, 'behat_wwwroot')) {
    $mockhash = sha1($CFG->behat_wwwroot);
} else {
    $mockhash = sha1($CFG->wwwroot);
}

if (!empty(getenv('BBBMOCKURL'))) {
    $bbbmockurl = getenv('BBBMOCKURL') . "/hash{$mockhash}";
    define("TEST_MOD_BIGBLUEBUTTONBN_MOCK_SERVER", $bbbmockurl);
}

if (!empty(getenv('MATRIXMOCKURL'))) {
    $matrixmockurl = getenv('MATRIXMOCKURL') . "/hash{$mockhash}";
    define("TEST_COMMUNICATION_MATRIX_MOCK_SERVER", $matrixmockurl);
}

if ($mlbackendpython = getenv('MLBACKENDTESTNAME')) {
    define('TEST_MLBACKEND_PYTHON_HOST', $mlbackendpython);
    define('TEST_MLBACKEND_PYTHON_PORT', 5000);
    define('TEST_MLBACKEND_PYTHON_USERNAME', 'default');
    define('TEST_MLBACKEND_PYTHON_PASSWORD', 'sshhhh');
}

if ($ionicurl = getenv('IONICURL')) {
    $CFG->behat_ionic_wwwroot = $ionicurl;
}

require_once(__DIR__ . '/lib/setup.php');

/**
 * Configuration utility for the CI runner.
 */
class moodlehq_ci_runner {
    public static function job_type_matches(string $type): bool {
        $jobtype = getenv('JOBTYPE');
        if ($jobtype) {
            return ($jobtype === $type);
        }
        return true;
    }

    /**
     * Set behat configuration.
     *
     * @param string $behathostname
     * @param string $browsername
     * @param string $runcount
     * @param bool $usetimingfile
     * @param string $timeoutfactor
     */
    public static function set_behat_configuration(
        string $behathostname,
        string $browsername,
        string $runcount,
        bool $usetimingfile,
        string $timeoutfactor
    ) {
        global $CFG;

        $CFG->behat_wwwroot   = "http://{$behathostname}";
        $CFG->behat_dataroot  = '/var/www/behatdata/run';
        $CFG->behat_prefix = 'b_';

        self::configure_profiles_for_browser($browsername, $runcount);

        $CFG->behat_faildump_path = '/shared';

        if ($usetimingfile) {
            define('BEHAT_FEATURE_TIMING_FILE', '/shared/timing.json');
        }

        if ($timeoutfactor) {
            $CFG->behat_increasetimeout = $timeoutfactor;
        }
    }

    /**
     * Given a JSON-encoded $configuration, apply for those settings to the current configuration.
     *
     * Note that they are always of the form: "key": "value" and can be:
     * - global settings: That will be applied to the main CFG. {"directorypermissions": "00777"}
     * - plugin settings: That will be applied via GFG->forced_plugin_settings. {"antivirus_clamav/pathtoclam": "/usr/clamscan"}
     *
     * @param string $config JSON-encoded configuration pairs to be applied to current configuration.
     * @return void
     */
    public static function apply_config_settings(string $config) {
        global $CFG;

        // We always want this set in order to allow behat to see custom components configurations.
        $CFG->behat_extraallowedsettings = array('forced_plugin_settings');

        $settings = @json_decode($config, true) ?: []; // Decode as associative array.
        foreach ($settings as $setting => $value) {
            if (strpos($setting, '/') === false) {
                // This is a global config setting.
                $CFG->{$setting} = $value;
            } else {
                // This is a component config setting.
                list($plugin, $key) = explode('/', $setting);
                if (!isset($CFG->forced_plugin_settings[$plugin])) {
                    $CFG->forced_plugin_settings[$plugin] = [];
                }
                $CFG->forced_plugin_settings[$plugin][$key] = $value;
            }
        }
    }

    /**
     * Get the configuration for the specified browser.
     *
     * @param string $browsername
     * @param string $runcount
     */
    public static function configure_profiles_for_browser(string $browser, string $runs) {
        global $CFG;
        switch ($browser) {
            case 'chrome':
                $profile = self::get_chrome_profile();
                break;
            case 'firefox':
                $profile = self::get_firefox_profile();
                break;
            default:
                $profile = [];
                break;
        }

        // Set the default profile to use the first selenium URL only.
        $profile['wd_host'] = getenv('SELENIUMURL_1') . '/wd/hub';

        $CFG->behat_profiles = [];
        $CFG->behat_profiles[$browser] = $profile;

        if ($runs > 1) {
            // There is more than one parallel run..
            // Set the wd URL in the behat_parallel_run array.
            $CFG->behat_parallel_run = [];
            for ($run = 0; $run <= $runs; $run++) {
                $CFG->behat_parallel_run[$run] = [
                    'wd_host' => getenv("SELENIUMURL_{$run}") . '/wd/hub',
                ];

                // Copy the profile for re-runs.
                $profile['wd_host'] = getenv("SELENIUMURL_{$run}") . '/wd/hub';
                $CFG->behat_profiles["{$browser}{$run}"] = $profile;
            }
        }
    }

    /**
     * Get the configuration for Chrome.
     *
     * @return array
     */
    protected static function get_chrome_profile(): array {
        $profile = [
            'browser' => 'chrome',
            'capabilities' => [
                'browserName' => 'chrome',
                'extra_capabilities' => [
                    'goog:chromeOptions' => [
                        'args' => [
                            // Disable the sandbox.
                            // https://peter.sh/experiments/chromium-command-line-switches/#no-sandbox
                            // Recommended for testing.
                            'no-sandbox',

                            // Disable use of GPU hardware acceleration.
                            // https://peter.sh/experiments/chromium-command-line-switches/#disable-gpu
                            //
                            // This ensures that the rendering is done in software and works around a bug in Chrome.
                            // This may be fixed by https://bugs.chromium.org/p/chromedriver/issues/detail?id=3667 but we
                            // cannot upgrade until Chrome 89 is released due to another bug in Chromedriver.
                            'no-gpu',
                        ],
                    ],
                ],
            ],
        ];

        if (getenv('BROWSER_DEBUG')) {
            // Chrome has no documented debug logging via capabilities.
            // These may exist but are undocumented.
        }

        if (getenv('BROWSER_HEADLESS')) {
            $profile = array_merge_recursive(
                $profile,
                [
                    // Chrome headless mode.
                    //
                    // Add the 'headless' argument to chrome.
                    // https://peter.sh/experiments/chromium-command-line-switches/#headless
                    //
                    // Note: Chrome args _should not_ include the leading `--`.
                    // https://chromedriver.chromium.org/capabilities
                    'capabilities' => [
                        'extra_capabilities' => [
                            'goog:chromeOptions' => [
                                'args' => [
                                    // Headless mode is going away with new Selenium versions and Chrome.
                                    // This is backwards compatinble with older versions of Selenium.
                                    'headless=new',
                                ],
                            ],
                        ],
                    ],
                ]
            );
        }

        if (getenv('BROWSER_CHROME_ARGS')) {
            $profile = array_merge_recursive(
                $profile,
                [
                    'capabilities' => [
                        'extra_capabilities' => [
                            'goog:chromeOptions' => [
                                'args' => explode(',', getenv('BROWSER_CHROME_ARGS')),
                            ],
                        ],
                    ],
                ]
            );
        }

        return $profile;
    }

    /**
     * Get the configuration for Chrome.
     *
     * @return array
     */
    protected static function get_firefox_profile(): array {
        $profile = [
            'browser' => 'firefox',
            'capabilities' => [
                'browserName' => 'firefox',
                'extra_capabilities' => [],
            ],
        ];

        if (getenv('BROWSER_DEBUG')) {
            $profile = array_merge_recursive(
                $profile,
                [
                    // Increase verbosity for Firefox.
                    'capabilities' => [
                        'extra_capabilities' => [
                            'moz:firefoxOptions' => [
                                'prefs' => [
                                    // Write the developer console to STDOUT.
                                    'devtools.console.stdout.content' => true,
                                ],
                                'log' => [
                                    // Set log level to 'trace'.
                                    // https://firefox-source-docs.mozilla.org/testing/geckodriver/TraceLogs.html
                                    'level' => 'trace',
                                ],
                            ],
                        ],
                    ],
                ]
            );

        }

        if (getenv('BROWSER_HEADLESS')) {
            $profile = array_merge_recursive(
                $profile,
                [
                    // Firefox headless mode.
                    //
                    // Add the '-headless' argument to firefox.
                    // https://developer.mozilla.org/en-US/docs/Mozilla/Firefox/Headless_mode
                    //
                    // Note: Firefox args _must_ include the leading `-`.
                    // https://developer.mozilla.org/en-US/docs/Web/WebDriver/Capabilities/firefoxOptions#args
                    'capabilities' => [
                        'extra_capabilities' => [
                            'moz:firefoxOptions' => [
                                'args' => [
                                    '-headless',
                                ],
                            ],
                        ],
                    ],
                ]
            );
        }

        if (getenv('BROWSER_FIREFOX_ARGS')) {
            $profile = array_merge_recursive(
                $profile,
                [
                    'capabilities' => [
                        'extra_capabilities' => [
                            'moz:firefoxOptions' => [
                                'args' => explode(',', getenv('BROWSER_FIREFOX_ARGS')),
                            ],
                        ],
                    ],
                ]
            );
        }

        return $profile;
    }
}
