## 0.0.18

- Avoid installation of backitup in fresh installations

## 0.0.17

- Remove backitup instance in fresh_install

## 0.0.16

- Upgrade all adapters on fresh install
- Improved error handling

## 0.0.15

- Setting hostname to "this" on every start

## 0.0.14

- Added missing translations
- Fixed startup error in mqtt-client setup

## 0.0.13

- Added option to install and configure mqtt-client instance
- Map country codes correctly

## 0.0.12

- Fix: Allow iobroker user to use s6 commands (for upgrade)
- Updated maintenance script

## 0.0.11

- Implemented docker healthcheck
- Fixed: Fake official docker image version (> 8.1.0) to support ui upgrades via maintenance.sh

## 0.0.10

- Implemented js-controller upgrade via UI

## 0.0.9

- Fixed: hass instance is not created
- Optimized s6-scripts

## 0.0.8

- SUPERVISOR_TOKEN was missing in setup scripts
- Transfer system config from home assistant to ioBroker

## 0.0.7

- Transfer system config from home assistant to ioBroker
- Configure hass instance automatically

## 0.0.6

- Added support for installing extra packages via apt
- Added translations for add-on options
- Added automatic changelog update via GitHub workflow
- Fixed: removed nginx subfilter workaround for ioBroker Admin (reverted)

## 0.0.5

- Added option to install and configure hass adapter automatically
- Added translations for add-on options
- Added support for installing extra packages via apt
- Fixed: removed nginx subfilter workaround for ioBroker Admin (reverted)

## 0.0.4

- Added automatic first-start preparation of ioBroker data directory
- Added USB device access support
- Added option to install and auto-configure the hass adapter

## 0.0.3

- Fixed image naming for multi-architecture builds

## 0.0.2

- Separated container images per platform (amd64 / aarch64)

## 0.0.1

- Initial release
- Added nginx reverse proxy for ioBroker Admin ingress
- Added Node.js 22.x support
- Added GitHub release workflow
