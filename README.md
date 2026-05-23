#### Fixed calendar plugin support

Quickclock creates a Plasma MonthView with an EventPluginsManager, but it never
persists or binds enabled calendar plugins. As a result, the Holidays calendar
plugin for example is never loaded, so holiday regions configured through
Plasma cannot appear in quickclock's popup calendar.

This patch adds the minimal calendar configuration used by Plasma's digital
clock: persists enabled calendar plugins, binds them into the popup calendar,
exposes the Calendar add-on list, and surfaces enabled plugin configuration
pages such as the Holidays region selector. It also wires week-number and
first-day-of-week settings to MonthView for consistency with the calendar
configuration UI.

It makes the Calendar config page explicitly track and save all calendar
settings so Apply/OK reliably persists plugin, week-number, and
first-day-of-week changes.

Restarting Plasma is required for the plugins to show. This can be done by
logging in or out. I have updated the installer to apply the patch when needed
and to restart Plasma shell for patched installs, it uses the user systemd
service before falling back to the legacy plasmashell restart path for
robustness.

#### Notes:

Only Holiday support has really been tested in use atm, but not to a
large degree. Your mileage may wary on using any other plugin.

