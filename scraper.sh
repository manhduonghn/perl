#!/bin/bash
perl github.pl
perl apkmirror.pl 'google-inc' 'youtube-music' 'com.google.android.apps.youtube.music' 'arm64-v8a'
perl apkmirror.pl 'google-inc' 'youtube' 'com.google.android.youtube'
perl uptodown.pl 'youtube-music' 'com.google.android.apps.youtube.music'
perl uptodown.pl 'youtube' 'com.google.android.youtube'
perl apkpure.pl 'youtube-music' 'com.google.android.apps.youtube.music'
perl apkpure.pl 'youtube' 'com.google.android.youtube'