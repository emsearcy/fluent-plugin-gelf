# Fluentd GELF output and formatter plugins

## Overview
Fluentd GELF output and formatter plugins.

## Installation
```bash
gem install fluent-plugin-gelf
```

## Output plugin configuration
```
<match **>
  type gelf
  host <remote GELF host>
  port <remote GELF port>
  protocol <tcp or udp (default)>
  [ fluent buffered output plugin configuration ]
</match>
```

## Formatter plugin configuration
```
<match **>
  type file (any type that that takes a format argument)
  format gelf
  [ fluent file output plugin configuration ]
</match>
```
