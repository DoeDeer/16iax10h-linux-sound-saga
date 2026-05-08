# After installation steps

After you isntalled built kernel RPMs, there are few additinonal steps needed to make things operate properly.

## Default kernel selection

You may want now to change your default boot kernel:
```shell
sudo grubby --set-default /boot/vmlinuz-<your-new-kernel-configuration>
```
