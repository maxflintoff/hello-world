# Express Hello World & Automation tools

This repository contains a collection of tools that allows you to automate deployment of the Express application contained in the /app directory.

## /app

This directory contains a simple application written in Javascript based on the Express framework. The application is designed to be run on a container orchestration platform such as kubernetes

## /manifests

This directory contains manifests for deploying Currently only containing one directory /manifest/k8s that contains kubernetes manifests for deploying the application once built into a container image. The pipelines (outlined below) use these manifests to automate deployment

## /pipelines

This directory contains manifests for automating build and deployment of the application in this repository. Currently it contains a directory /pipelines/tekton that can be used to recreate this work on a kubernetes platform with [tekton pipelines](https://github.com/tektoncd/pipeline) and [tekton triggers](https://github.com/tektoncd/triggers). It expects 3 namespaces: hw-pipeline, hw-dev, hw-test to exist prior to being run and rbac.yaml should be adjusted for your environment (tested on openshift 4.6). Once all the artifacts are present in your environment you can trigger a manual build with the pipeline-run.yaml, ensuring to adjust the values for your environment.
