# Master-guided 96×128 reconstruction

- The generated 16-bit fisherman is a visual master only; no master pixels are sampled into the atlas. The new 384×512 atlas is manually reconstructed at native 96×128 cells.
- Clusters carry the master cues: expressive eye and nose profile, navy cap/hair, teal jacket with cream inner layer, orange trouser planes, brown boots, asymmetrical olive tackle bag and rod/reel.
- Foot anchor remains local y=126 with the existing shadow/collider concept. Atlas preserves four facings × four walk frames and stride offsets.
- Runtime files are untouched. If adopted, uncompressed atlas is 768 KiB and frame source/destination regions become 96×128; draw count/collider/map scale remain unchanged.
