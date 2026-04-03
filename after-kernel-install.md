# After installation steps

After you isntalled built kernel RPMs, there are few additinonal steps needed to make things operate properly.

## Default kernel selection

You may want now to finish kernel configuration (to use non default sound driver) and change your default boot kernel.
To update kernel configuration, add `snd_intel_dspcfg.dsp_driver=3` to the end of `options` line at `/boot/loader/entries/<your-new-kernel-configuration>.conf`
```shell
sudo nano /boot/loader/entries/<your-new-kernel-configuration>.conf
```

To change the default boot kernel:
```shell
sudo grubby --set-default /boot/vmlinuz-<your-new-kernel-configuration>
```

## Sound configuration

Finally - re-apply sound settings:
```shell
sudo cp -f fix/ucm2/HiFi-analog.conf /usr/share/alsa/ucm2/HDA/HiFi-analog.conf
sudo cp -f fix/ucm2/HiFi-mic.conf /usr/share/alsa/ucm2/HDA/HiFi-mic.conf
```

and calibrate speaker. It's required to replace `hw:0` and `-c 0` with your actual hw id which can get from `alsaucm listcards`:
```shell
alsaucm -c hw:0 reset
alsaucm -c hw:0 reload
systemctl --user restart pipewire pipewire-pulse wireplumber
amixer sset -c 0 Master 100%
amixer sset -c 0 Headphone 100%
amixer sset -c 0 Speaker 100%
```
