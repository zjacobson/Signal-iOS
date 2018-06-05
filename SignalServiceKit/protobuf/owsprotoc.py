#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import subprocess 
import datetime
import argparse
import commands


def compile_objc(input_file_path, out_dir_path, objc_cmd):
    print 'compiling to obj-c:', input_file_path
    objc_cmd = ' '.join((objc_cmd, 
        ("--objc_out='%s'" % (out_dir_path)),
        input_file_path))
    print '\t', objc_cmd
    print commands.getoutput(objc_cmd)
    print


def compile_swft(input_file_path, out_dir_path, swift_cmd):
    print 'compiling to swift:', input_file_path
    swift_cmd = ' '.join((swift_cmd, 
        ("--swift_out='%s'" % (out_dir_path)),
        input_file_path))
    print '\t', swift_cmd
    print commands.getoutput(swift_cmd)
    print


if __name__ == "__main__":
    
    parser = argparse.ArgumentParser(description='Precommit script.')
    parser.add_argument('--objc-cmd', required=True, help='Objective-C proto compiler command')
    parser.add_argument('--swift-cmd', required=True, help='Swift proto compiler command')
    parser.add_argument('--out-dir', required=True, help='destination directory for generated files.')
    parser.add_argument('inputs', metavar='N', type=str, nargs='+',
                        help='a .proto schema file to compilet')
    args = parser.parse_args()
    
    print 'obj-c cmd', args.objc_cmd
    print 'swift cmd', args.swift_cmd
    print 'out', args.out_dir
    print 'inputs', args.inputs
    
    for input in args.inputs:
        # This requires protobuf@2.6
        # compile_objc(input, args.out_dir, args.objc_cmd)
        
        # This requires protobuf@3.3 or later.
        compile_swft(input, args.out_dir, args.swift_cmd)
    
    print 'Complete.'
