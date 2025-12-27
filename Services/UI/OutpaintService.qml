pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.System

Singleton {
  id: root

  // Outpaint provider: "edge_extend", "comfyui"
  property string provider: Settings.data.wallpaper.outpaintProvider ?? "edge_extend"

  // ComfyUI settings
  property string comfyuiUrl: Settings.data.wallpaper.outpaintComfyuiUrl ?? "http://127.0.0.1:8188"
  property string comfyuiCheckpoint: Settings.data.wallpaper.outpaintComfyuiCheckpoint ?? ""
  property int comfyuiSteps: Settings.data.wallpaper.outpaintComfyuiSteps ?? 20
  property real comfyuiDenoise: Settings.data.wallpaper.outpaintComfyuiDenoise ?? 0.75

  // Legacy SD settings (kept for migration)
  property string sdApiUrl: Settings.data.wallpaper.outpaintSdApiUrl ?? "http://127.0.0.1:7860"
  property string sdModel: Settings.data.wallpaper.outpaintSdModel ?? ""

  // Preferred extend direction: "auto", "horizontal", "vertical"
  property string extendDirection: Settings.data.wallpaper.outpaintDirection ?? "auto"

  // Auto-outpaint when applying mismatched wallpapers
  property bool autoOutpaint: Settings.data.wallpaper.outpaintAuto ?? false

  // Processing state
  property bool isProcessing: false
  property string processingFile: ""
  property real progress: 0.0
  property string progressStage: ""

  // Outpainted wallpapers cache directory
  readonly property string cacheDir: Settings.cacheDir + "outpainted/"

  // Signals
  signal outpaintCompleted(string originalPath, string outpaintedPath)
  signal outpaintFailed(string originalPath, string error)

  function init() {
    Logger.i("Outpaint", "Service started");
    // Ensure cache directory exists
    ensureCacheDir();
  }

  function ensureCacheDir() {
    var mkdirProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["mkdir", "-p", "${cacheDir}"]
      }
    `, root, "MkdirProcess");
    mkdirProc.exited.connect(function() { mkdirProc.destroy(); });
    mkdirProc.running = true;
  }

  // Check if wallpaper needs outpainting for given screen dimensions
  function needsOutpaint(imagePath, screenWidth, screenHeight) {
    // This would need to check image dimensions vs screen dimensions
    // For now, return false as we'll calculate on demand
    return false;
  }

  // Calculate required padding for outpainting
  function calculatePadding(imageWidth, imageHeight, screenWidth, screenHeight) {
    var imageAspect = imageWidth / imageHeight;
    var screenAspect = screenWidth / screenHeight;

    if (Math.abs(imageAspect - screenAspect) < 0.01) {
      // Close enough, no outpainting needed
      return null;
    }

    var padding = { left: 0, right: 0, top: 0, bottom: 0, direction: "none" };

    if (extendDirection === "auto") {
      // Determine which direction needs less extension
      if (imageAspect < screenAspect) {
        // Image is taller, extend horizontally
        padding.direction = "horizontal";
        var newWidth = Math.round(imageHeight * screenAspect);
        var totalPad = newWidth - imageWidth;
        padding.left = Math.floor(totalPad / 2);
        padding.right = totalPad - padding.left;
      } else {
        // Image is wider, extend vertically
        padding.direction = "vertical";
        var newHeight = Math.round(imageWidth / screenAspect);
        var totalPad = newHeight - imageHeight;
        padding.top = Math.floor(totalPad / 2);
        padding.bottom = totalPad - padding.top;
      }
    } else if (extendDirection === "horizontal") {
      var newWidth = Math.round(imageHeight * screenAspect);
      var totalPad = Math.max(0, newWidth - imageWidth);
      padding.left = Math.floor(totalPad / 2);
      padding.right = totalPad - padding.left;
      padding.direction = "horizontal";
    } else {
      var newHeight = Math.round(imageWidth / screenAspect);
      var totalPad = Math.max(0, newHeight - imageHeight);
      padding.top = Math.floor(totalPad / 2);
      padding.bottom = totalPad - padding.top;
      padding.direction = "vertical";
    }

    return padding;
  }

  // Main outpaint function
  function outpaint(imagePath, screenWidth, screenHeight, callback) {
    if (isProcessing) {
      Logger.w("Outpaint", "Already processing");
      ToastService.showWarning(
        I18n.tr("wallpaper.outpaint.busy") || "Outpainting in Progress",
        I18n.tr("wallpaper.outpaint.busy-desc") || "Please wait for the current operation to complete"
      );
      return;
    }

    isProcessing = true;
    processingFile = imagePath;
    progress = 0.0;
    progressStage = "analyzing";

    Logger.i("Outpaint", "Starting outpaint for:", imagePath, "screen:", screenWidth, "x", screenHeight);

    // First, get image dimensions
    getImageDimensions(imagePath, function(width, height) {
      if (width <= 0 || height <= 0) {
        handleError(imagePath, "Failed to get image dimensions", callback);
        return;
      }

      var padding = calculatePadding(width, height, screenWidth, screenHeight);
      if (!padding || padding.direction === "none") {
        Logger.i("Outpaint", "No outpainting needed, aspect ratios match");
        isProcessing = false;
        processingFile = "";
        if (callback) callback(imagePath); // Return original
        return;
      }

      Logger.i("Outpaint", "Padding calculated:", JSON.stringify(padding));
      progress = 0.2;
      progressStage = "processing";

      // Generate output filename
      var filename = imagePath.split('/').pop();
      var baseName = filename.substring(0, filename.lastIndexOf('.'));
      var ext = filename.substring(filename.lastIndexOf('.') + 1);
      var outputPath = cacheDir + baseName + "_outpainted_" + screenWidth + "x" + screenHeight + "." + ext;

      if (provider === "comfyui") {
        outpaintWithComfyUI(imagePath, outputPath, padding, width, height, screenWidth, screenHeight, callback);
      } else {
        outpaintWithEdgeExtend(imagePath, outputPath, padding, callback);
      }
    });
  }

  // Get image dimensions using ImageMagick
  function getImageDimensions(imagePath, callback) {
    var dimProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["identify", "-format", "%wx%h", "${imagePath.replace(/"/g, '\\"')}"]
        stdout: StdioCollector {}
      }
    `, root, "DimProcess");

    dimProc.exited.connect(function(code) {
      if (code === 0) {
        var dims = dimProc.stdout.text.trim().split('x');
        if (dims.length === 2) {
          callback(parseInt(dims[0]), parseInt(dims[1]));
        } else {
          callback(-1, -1);
        }
      } else {
        callback(-1, -1);
      }
      dimProc.destroy();
    });
    dimProc.running = true;
  }

  // Edge extension using ImageMagick (simple but fast)
  function outpaintWithEdgeExtend(imagePath, outputPath, padding, callback) {
    progressStage = "extending";
    progress = 0.4;

    // Use ImageMagick to extend edges
    // -gravity center -background none -extent WxH for basic extension
    // -distort SRT for edge sampling
    var newWidth = 0;
    var newHeight = 0;

    // Calculate new dimensions
    var dimProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["identify", "-format", "%wx%h", "${imagePath.replace(/"/g, '\\"')}"]
        stdout: StdioCollector {}
      }
    `, root, "DimProcess2");

    dimProc.exited.connect(function(code) {
      if (code !== 0) {
        handleError(imagePath, "Failed to get dimensions", callback);
        dimProc.destroy();
        return;
      }

      var dims = dimProc.stdout.text.trim().split('x');
      var origWidth = parseInt(dims[0]);
      var origHeight = parseInt(dims[1]);
      newWidth = origWidth + padding.left + padding.right;
      newHeight = origHeight + padding.top + padding.bottom;

      dimProc.destroy();
      progress = 0.5;

      // Use convert with edge-extend technique
      // Sample edge pixels and extend them outward with blur
      var cmd = `convert "${imagePath}" ` +
        `-gravity center ` +
        `-background "$(convert "${imagePath}" -gravity West -crop 1x100%+0+0 -resize 1x1! -format "%[pixel:u]" info:)" ` +
        `-splice ${padding.left}x0 ` +
        `-background "$(convert "${imagePath}" -gravity East -crop 1x100%+0+0 -resize 1x1! -format "%[pixel:u]" info:)" ` +
        `-gravity East -splice ${padding.right}x0 ` +
        `-background "$(convert "${imagePath}" -gravity North -crop 100%x1+0+0 -resize 1x1! -format "%[pixel:u]" info:)" ` +
        `-gravity North -splice 0x${padding.top} ` +
        `-background "$(convert "${imagePath}" -gravity South -crop 100%x1+0+0 -resize 1x1! -format "%[pixel:u]" info:)" ` +
        `-gravity South -splice 0x${padding.bottom} ` +
        `-blur 0x30 ` +
        `"${outputPath}"`;

      // Simpler approach: extend with edge color and blur
      var simpleCmd = `convert "${imagePath}" ` +
        `-bordercolor "$(convert "${imagePath}" -resize 1x1! -format "%[pixel:u]" info:)" ` +
        `-border ${padding.left}x${padding.top} ` +
        `\\\\( +clone -blur 0x50 \\\\) ` +
        `\\\\( -clone 0 -gravity center \\\\) ` +
        `-delete 0 -compose over -composite ` +
        `"${outputPath}"`;

      // Even simpler: just extend with edge sampling
      // Note: escape parentheses for bash when passing through Qt.createQmlObject
      var verySimpleCmd = `convert "${imagePath}" ` +
        `-gravity center ` +
        `-extent ${newWidth}x${newHeight} ` +
        `-blur 0x5 ` +
        `\\\\( "${imagePath}" \\\\) ` +
        `-gravity center -composite ` +
        `"${outputPath}"`;

      var extendProc = Qt.createQmlObject(`
        import QtQuick
        import Quickshell.Io
        Process {
          command: ["bash", "-c", \`${verySimpleCmd.replace(/`/g, "\\`")}\`]
          stdout: StdioCollector {}
          stderr: StdioCollector {}
        }
      `, root, "ExtendProcess");

      extendProc.exited.connect(function(exitCode) {
        progress = 1.0;

        if (exitCode === 0) {
          Logger.i("Outpaint", "Edge extend completed:", outputPath);
          isProcessing = false;
          processingFile = "";
          progressStage = "";
          outpaintCompleted(imagePath, outputPath);
          if (callback) callback(outputPath);
          ToastService.showNotice(
            I18n.tr("wallpaper.outpaint.completed") || "Outpainting Complete",
            I18n.tr("wallpaper.outpaint.completed-desc") || "Wallpaper has been extended"
          );
        } else {
          handleError(imagePath, extendProc.stderr.text || "ImageMagick failed", callback);
        }
        extendProc.destroy();
      });

      extendProc.running = true;
    });

    dimProc.running = true;
  }

  // Active ComfyUI prompt ID for polling
  property string _comfyuiPromptId: ""
  property var _comfyuiCallback: null
  property string _comfyuiOutputPath: ""
  property string _comfyuiOriginalPath: ""

  // Outpaint using ComfyUI API
  function outpaintWithComfyUI(imagePath, outputPath, padding, imageWidth, imageHeight, screenWidth, screenHeight, callback) {
    progressStage = "ai_processing";
    progress = 0.3;

    Logger.i("Outpaint", "Starting ComfyUI outpaint, API:", comfyuiUrl);

    // Check if ComfyUI API is available
    var checkProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "${comfyuiUrl}/system_stats"]
        stdout: StdioCollector {}
      }
    `, root, "ComfyUICheckProcess");

    checkProc.exited.connect(function(code) {
      var httpCode = checkProc.stdout.text.trim();
      checkProc.destroy();

      if (code !== 0 || httpCode !== "200") {
        Logger.w("Outpaint", "ComfyUI API not available at", comfyuiUrl, "status:", httpCode);
        ToastService.showWarning(
          I18n.tr("wallpaper.outpaint.comfyui-unavailable") || "ComfyUI Unavailable",
          I18n.tr("wallpaper.outpaint.comfyui-unavailable-desc") || "Falling back to edge extension"
        );
        outpaintWithEdgeExtend(imagePath, outputPath, padding, callback);
        return;
      }

      progress = 0.35;
      progressStage = "preparing";

      // Calculate new dimensions
      var newWidth = imageWidth + padding.left + padding.right;
      var newHeight = imageHeight + padding.top + padding.bottom;

      // Step 1: Upload the original image to ComfyUI
      uploadImageToComfyUI(imagePath, function(uploadedImageName) {
        if (!uploadedImageName) {
          handleError(imagePath, "Failed to upload image to ComfyUI", callback);
          return;
        }

        progress = 0.4;
        Logger.i("Outpaint", "Image uploaded as:", uploadedImageName);

        // Step 2: Create the outpaint mask (inverted - white=inpaint area)
        createOutpaintMask(imageWidth, imageHeight, padding, function(maskPath) {
          if (!maskPath) {
            handleError(imagePath, "Failed to create outpaint mask", callback);
            return;
          }

          progress = 0.45;

          // Step 3: Upload the mask to ComfyUI
          uploadImageToComfyUI(maskPath, function(uploadedMaskName) {
            if (!uploadedMaskName) {
              handleError(imagePath, "Failed to upload mask to ComfyUI", callback);
              return;
            }

            progress = 0.5;
            Logger.i("Outpaint", "Mask uploaded as:", uploadedMaskName);

            // Step 4: Create and extend the input image canvas
            createExtendedCanvas(imagePath, imageWidth, imageHeight, padding, function(extendedPath) {
              if (!extendedPath) {
                handleError(imagePath, "Failed to create extended canvas", callback);
                return;
              }

              progress = 0.55;

              // Upload extended image
              uploadImageToComfyUI(extendedPath, function(uploadedExtendedName) {
                if (!uploadedExtendedName) {
                  handleError(imagePath, "Failed to upload extended image", callback);
                  return;
                }

                progress = 0.6;
                progressStage = "generating";

                // Step 5: Build and queue the ComfyUI workflow
                queueComfyUIWorkflow(uploadedExtendedName, uploadedMaskName, newWidth, newHeight, imagePath, outputPath, callback);
              });
            });
          });
        });
      });
    });

    checkProc.running = true;
  }

  // Upload an image to ComfyUI's /upload/image endpoint
  function uploadImageToComfyUI(imagePath, callback) {
    Logger.d("Outpaint", "Uploading to ComfyUI:", imagePath);

    var uploadProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["curl", "-s", "-X", "POST", "${comfyuiUrl}/upload/image",
                  "-F", "image=@${imagePath.replace(/"/g, '\\"')}"]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `, root, "UploadProcess");

    uploadProc.exited.connect(function(code) {
      Logger.d("Outpaint", "Upload exit code:", code, "stdout:", uploadProc.stdout.text, "stderr:", uploadProc.stderr.text);

      if (code !== 0) {
        Logger.e("Outpaint", "Upload failed with code", code, "- stderr:", uploadProc.stderr.text);
        callback(null);
        uploadProc.destroy();
        return;
      }

      try {
        var response = JSON.parse(uploadProc.stdout.text);
        if (response.name) {
          Logger.d("Outpaint", "Upload successful, name:", response.name);
          callback(response.name);
        } else {
          Logger.e("Outpaint", "Upload response missing name:", uploadProc.stdout.text);
          callback(null);
        }
      } catch (e) {
        Logger.e("Outpaint", "Failed to parse upload response:", e, "stdout:", uploadProc.stdout.text);
        callback(null);
      }
      uploadProc.destroy();
    });

    uploadProc.running = true;
  }

  // Create an outpaint mask using ImageMagick
  function createOutpaintMask(imageWidth, imageHeight, padding, callback) {
    var newWidth = imageWidth + padding.left + padding.right;
    var newHeight = imageHeight + padding.top + padding.bottom;
    var maskPath = "/tmp/comfyui_outpaint_mask_" + Date.now() + ".png";

    // Create mask: white background, black rectangle where original image is
    // ComfyUI inpainting: white = areas to generate, black = areas to keep
    var cmd = `convert -size ${newWidth}x${newHeight} xc:white ` +
      `-fill black -draw "rectangle ${padding.left},${padding.top} ${padding.left + imageWidth - 1},${padding.top + imageHeight - 1}" ` +
      `"${maskPath}"`;

    var maskProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["bash", "-c", \`${cmd}\`]
        stderr: StdioCollector {}
      }
    `, root, "MaskProcess");

    maskProc.exited.connect(function(code) {
      if (code === 0) {
        callback(maskPath);
      } else {
        Logger.e("Outpaint", "Mask creation failed:", maskProc.stderr.text);
        callback(null);
      }
      maskProc.destroy();
    });

    maskProc.running = true;
  }

  // Create extended canvas with original image centered
  function createExtendedCanvas(imagePath, imageWidth, imageHeight, padding, callback) {
    var newWidth = imageWidth + padding.left + padding.right;
    var newHeight = imageHeight + padding.top + padding.bottom;
    var extendedPath = "/tmp/comfyui_outpaint_extended_" + Date.now() + ".png";

    Logger.d("Outpaint", "Creating extended canvas:", newWidth, "x", newHeight, "from", imagePath);

    // Create canvas with edge-sampled background color, place original image on top
    var cmd = `convert "${imagePath}" ` +
      `-gravity center -background "$(convert "${imagePath}" -resize 1x1! -format "%[pixel:u]" info:)" ` +
      `-extent ${newWidth}x${newHeight} ` +
      `"${extendedPath}"`;

    Logger.d("Outpaint", "Extended canvas command:", cmd);

    var extendProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["bash", "-c", \`${cmd}\`]
        stdout: StdioCollector {}
        stderr: StdioCollector {}
      }
    `, root, "ExtendProcess");

    extendProc.exited.connect(function(code) {
      Logger.d("Outpaint", "Extended canvas exit code:", code, "stderr:", extendProc.stderr.text);

      if (code === 0) {
        Logger.d("Outpaint", "Extended canvas created:", extendedPath);
        callback(extendedPath);
      } else {
        Logger.e("Outpaint", "Extended canvas creation failed with code", code, "- stderr:", extendProc.stderr.text);
        callback(null);
      }
      extendProc.destroy();
    });

    extendProc.running = true;
  }

  // Queue the ComfyUI workflow
  function queueComfyUIWorkflow(imageName, maskName, width, height, originalPath, outputPath, callback) {
    // Round dimensions to multiple of 8 for stable diffusion
    var roundedWidth = Math.ceil(width / 8) * 8;
    var roundedHeight = Math.ceil(height / 8) * 8;

    // Get checkpoint to use
    var checkpoint = comfyuiCheckpoint || "sd_xl_base_1.0.safetensors";

    // Build ComfyUI workflow for inpainting/outpainting
    var workflow = {
      "3": {
        "class_type": "KSampler",
        "inputs": {
          "cfg": 7,
          "denoise": comfyuiDenoise,
          "latent_image": ["14", 0],
          "model": ["4", 0],
          "negative": ["7", 0],
          "positive": ["6", 0],
          "sampler_name": "euler_ancestral",
          "scheduler": "normal",
          "seed": Math.floor(Math.random() * 1000000000),
          "steps": comfyuiSteps
        }
      },
      "4": {
        "class_type": "CheckpointLoaderSimple",
        "inputs": {
          "ckpt_name": checkpoint
        }
      },
      "6": {
        "class_type": "CLIPTextEncode",
        "inputs": {
          "clip": ["4", 1],
          "text": "seamless extension, natural continuation, consistent lighting, high quality, detailed"
        }
      },
      "7": {
        "class_type": "CLIPTextEncode",
        "inputs": {
          "clip": ["4", 1],
          "text": "text, watermark, signature, artifacts, blurry, low quality, seams, visible edges"
        }
      },
      "8": {
        "class_type": "VAEDecode",
        "inputs": {
          "samples": ["3", 0],
          "vae": ["4", 2]
        }
      },
      "9": {
        "class_type": "SaveImage",
        "inputs": {
          "filename_prefix": "outpaint",
          "images": ["8", 0]
        }
      },
      "10": {
        "class_type": "LoadImage",
        "inputs": {
          "image": imageName
        }
      },
      "11": {
        "class_type": "LoadImage",
        "inputs": {
          "image": maskName
        }
      },
      "14": {
        "class_type": "VAEEncodeForInpaint",
        "inputs": {
          "grow_mask_by": 6,
          "pixels": ["10", 0],
          "mask": ["11", 0],
          "vae": ["4", 2]
        }
      }
    };

    var prompt = {
      "prompt": workflow,
      "client_id": "noctalia_outpaint_" + Date.now()
    };

    var promptJson = JSON.stringify(prompt);
    var tmpFile = "/tmp/comfyui_prompt_" + Date.now() + ".json";

    // Write prompt to temp file using base64 to avoid escaping issues
    var base64Json = Qt.btoa(promptJson);
    var writeProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["bash", "-c", "echo '${base64Json}' | base64 -d > '${tmpFile}'"]
        stderr: StdioCollector {}
      }
    `, root, "WritePrompt");

    writeProc.exited.connect(function(code) {
      if (code !== 0) {
        Logger.e("Outpaint", "Failed to write prompt file:", writeProc.stderr.text);
        handleError(originalPath, "Failed to write prompt file", callback);
        writeProc.destroy();
        return;
      }
      writeProc.destroy();

      // Queue the prompt
      var queueProc = Qt.createQmlObject(`
        import QtQuick
        import Quickshell.Io
        Process {
          command: ["curl", "-s", "-X", "POST", "${comfyuiUrl}/prompt",
                   "-H", "Content-Type: application/json",
                   "-d", "@${tmpFile}"]
          stdout: StdioCollector {}
          stderr: StdioCollector {}
        }
      `, root, "QueueProcess");

      queueProc.exited.connect(function(code) {
        // Clean up temp file
        Qt.createQmlObject(`
          import QtQuick
          import Quickshell.Io
          Process { command: ["rm", "-f", "${tmpFile}"] }
        `, root, "CleanupTmp").running = true;

        if (code !== 0) {
          handleError(originalPath, "Failed to queue ComfyUI prompt", callback);
          queueProc.destroy();
          return;
        }

        try {
          var response = JSON.parse(queueProc.stdout.text);
          if (response.prompt_id) {
            _comfyuiPromptId = response.prompt_id;
            _comfyuiCallback = callback;
            _comfyuiOutputPath = outputPath;
            _comfyuiOriginalPath = originalPath;

            Logger.i("Outpaint", "ComfyUI prompt queued:", _comfyuiPromptId);
            progress = 0.65;

            // Start polling for completion
            comfyuiPollTimer.start();
          } else if (response.error) {
            handleError(originalPath, "ComfyUI error: " + response.error, callback);
          } else {
            handleError(originalPath, "Invalid ComfyUI response", callback);
          }
        } catch (e) {
          handleError(originalPath, "Failed to parse ComfyUI response: " + e, callback);
        }

        queueProc.destroy();
      });

      queueProc.running = true;
    });

    writeProc.running = true;
  }

  // Timer to poll ComfyUI for completion
  Timer {
    id: comfyuiPollTimer
    interval: 1000
    repeat: true
    onTriggered: pollComfyUIStatus()
  }

  property int _pollAttempts: 0
  property int _maxPollAttempts: 300 // 5 minutes max

  function pollComfyUIStatus() {
    _pollAttempts++;

    if (_pollAttempts > _maxPollAttempts) {
      comfyuiPollTimer.stop();
      _pollAttempts = 0;
      handleError(_comfyuiOriginalPath, "ComfyUI generation timed out", _comfyuiCallback);
      return;
    }

    var historyProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["curl", "-s", "${comfyuiUrl}/history/${_comfyuiPromptId}"]
        stdout: StdioCollector {}
      }
    `, root, "HistoryProcess");

    historyProc.exited.connect(function(code) {
      if (code !== 0) {
        historyProc.destroy();
        return; // Will retry on next poll
      }

      try {
        var history = JSON.parse(historyProc.stdout.text);
        var promptHistory = history[_comfyuiPromptId];

        if (promptHistory && promptHistory.outputs) {
          // Generation complete!
          comfyuiPollTimer.stop();
          _pollAttempts = 0;

          progress = 0.9;
          progressStage = "saving";

          // Find the output image
          var outputNode = promptHistory.outputs["9"]; // SaveImage node
          if (outputNode && outputNode.images && outputNode.images.length > 0) {
            var outputImage = outputNode.images[0];
            var filename = outputImage.filename;
            var subfolder = outputImage.subfolder || "";

            // Download the result image
            downloadComfyUIResult(filename, subfolder, _comfyuiOutputPath, _comfyuiOriginalPath, _comfyuiCallback);
          } else {
            handleError(_comfyuiOriginalPath, "No output image in ComfyUI response", _comfyuiCallback);
          }
        } else {
          // Still processing, update progress estimate
          progress = Math.min(0.85, 0.65 + (_pollAttempts / _maxPollAttempts) * 0.2);
        }
      } catch (e) {
        // Parse error, likely empty response - will retry
      }

      historyProc.destroy();
    });

    historyProc.running = true;
  }

  // Download the result image from ComfyUI
  function downloadComfyUIResult(filename, subfolder, outputPath, originalPath, callback) {
    var viewUrl = comfyuiUrl + "/view?filename=" + encodeURIComponent(filename);
    if (subfolder) {
      viewUrl += "&subfolder=" + encodeURIComponent(subfolder);
    }

    var downloadProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["curl", "-s", "-o", "${outputPath}", "${viewUrl}"]
        stderr: StdioCollector {}
      }
    `, root, "DownloadProcess");

    downloadProc.exited.connect(function(code) {
      progress = 1.0;

      if (code === 0) {
        Logger.i("Outpaint", "ComfyUI outpaint completed:", outputPath);
        isProcessing = false;
        processingFile = "";
        progressStage = "";
        _comfyuiPromptId = "";
        outpaintCompleted(originalPath, outputPath);
        if (callback) callback(outputPath);
        ToastService.showNotice(
          I18n.tr("wallpaper.outpaint.completed") || "AI Outpainting Complete",
          I18n.tr("wallpaper.outpaint.completed-desc") || "Wallpaper has been extended with AI"
        );
      } else {
        handleError(originalPath, "Failed to download result from ComfyUI", callback);
      }

      downloadProc.destroy();
    });

    downloadProc.running = true;
  }

  function handleError(imagePath, error, callback) {
    Logger.e("Outpaint", "Error:", error);
    isProcessing = false;
    processingFile = "";
    progress = 0;
    progressStage = "";
    outpaintFailed(imagePath, error);
    ToastService.showError(
      I18n.tr("wallpaper.outpaint.failed") || "Outpainting Failed",
      error
    );
    if (callback) callback(null);
  }

  // Clear outpaint cache
  function clearCache() {
    Quickshell.execDetached(["rm", "-rf", cacheDir]);
    Quickshell.execDetached(["mkdir", "-p", cacheDir]);
    Logger.i("Outpaint", "Cache cleared");
    ToastService.showNotice(
      I18n.tr("wallpaper.outpaint.cache-cleared") || "Cache Cleared",
      I18n.tr("wallpaper.outpaint.cache-cleared-desc") || "Outpaint cache has been cleared"
    );
  }

  // Set provider
  function setProvider(value) {
    provider = value;
    Settings.data.wallpaper.outpaintProvider = value;
  }

  // Set extend direction
  function setExtendDirection(value) {
    extendDirection = value;
    Settings.data.wallpaper.outpaintDirection = value;
  }

  // Set auto outpaint
  function setAutoOutpaint(value) {
    autoOutpaint = value;
    Settings.data.wallpaper.outpaintAuto = value;
  }

  // Set ComfyUI URL
  function setComfyuiUrl(value) {
    comfyuiUrl = value;
    Settings.data.wallpaper.outpaintComfyuiUrl = value;
  }

  // Set ComfyUI checkpoint
  function setComfyuiCheckpoint(value) {
    comfyuiCheckpoint = value;
    Settings.data.wallpaper.outpaintComfyuiCheckpoint = value;
  }

  // Set ComfyUI steps
  function setComfyuiSteps(value) {
    comfyuiSteps = value;
    Settings.data.wallpaper.outpaintComfyuiSteps = value;
  }

  // Set ComfyUI denoise strength
  function setComfyuiDenoise(value) {
    comfyuiDenoise = value;
    Settings.data.wallpaper.outpaintComfyuiDenoise = value;
  }

  // Fetch available checkpoints from ComfyUI
  function fetchCheckpoints(callback) {
    var fetchProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["curl", "-s", "${comfyuiUrl}/object_info/CheckpointLoaderSimple"]
        stdout: StdioCollector {}
      }
    `, root, "FetchCheckpoints");

    fetchProc.exited.connect(function(code) {
      if (code === 0) {
        try {
          var response = JSON.parse(fetchProc.stdout.text);
          if (response.CheckpointLoaderSimple && response.CheckpointLoaderSimple.input &&
              response.CheckpointLoaderSimple.input.required &&
              response.CheckpointLoaderSimple.input.required.ckpt_name) {
            var checkpoints = response.CheckpointLoaderSimple.input.required.ckpt_name[0];
            if (callback) callback(checkpoints);
          } else {
            if (callback) callback([]);
          }
        } catch (e) {
          Logger.e("Outpaint", "Failed to parse checkpoints:", e);
          if (callback) callback([]);
        }
      } else {
        if (callback) callback([]);
      }
      fetchProc.destroy();
    });

    fetchProc.running = true;
  }

  // Test ComfyUI connection
  function testConnection(callback) {
    var testProc = Qt.createQmlObject(`
      import QtQuick
      import Quickshell.Io
      Process {
        command: ["curl", "-s", "-o", "/dev/null", "-w", "%{http_code}", "${comfyuiUrl}/system_stats"]
        stdout: StdioCollector {}
      }
    `, root, "TestConnection");

    testProc.exited.connect(function(code) {
      var httpCode = testProc.stdout.text.trim();
      var success = (code === 0 && httpCode === "200");
      if (callback) callback(success);
      testProc.destroy();
    });

    testProc.running = true;
  }
}
