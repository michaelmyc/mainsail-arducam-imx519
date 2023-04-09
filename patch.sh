if [ -n "diff /usr/share/libcamera/ipa/raspberrypi/imx519.json ./imx519.json" ]; then
    echo "The \"/usr/share/libcamera/ipa/raspberrypi/imx519.json\" file in your system does not satisfy requirements for automatic \
patching. Please manually patch the file."
    exit 1
fi

patch /usr/share/libcamera/ipa/raspberrypi/imx519.json ./add-autofocus.patch