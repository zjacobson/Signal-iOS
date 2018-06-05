#!/usr/bin/env python
# -*- coding: utf-8 -*-

import os
import sys
import subprocess 
import datetime
import argparse
import commands
import re


def compile_objc(input_file_path, out_dir_path, objc_cmd):
    # input_file_path = os.path.abspath(os.path.join(os.curdir, input_file_path))
    out_dir_path = os.path.abspath(os.path.join(os.curdir, out_dir_path))

    print 'compiling to obj-c:', input_file_path
    objc_cmd = ' '.join((objc_cmd, 
        ("--objc_out='%s'" % (out_dir_path)),
        input_file_path))
    print '\t', objc_cmd
    print commands.getoutput(objc_cmd)
    print


def compile_swft(input_file_path, out_dir_path, swift_cmd):
    # input_file_path = os.path.abspath(os.path.join(os.curdir, input_file_path))
    out_dir_path = os.path.abspath(os.path.join(os.curdir, out_dir_path))
    
    print 'compiling to swift:', input_file_path
    swift_cmd = ' '.join((swift_cmd, 
        ("--swift_out='%s'" % (out_dir_path)),
        input_file_path))
    print '\t', swift_cmd
    print commands.getoutput(swift_cmd)
    print

    for rootdir, dirnames, filenames in os.walk(out_dir_path):
        for filename in filenames:
            if not filename.endswith('.pb.swift'):
                continue
            swift_file_path = os.path.abspath(os.path.join(out_dir_path, filename))
            print '\t', 'post-processing:', swift_file_path
            patterns = (
                # ('struct (.+)', '@obj class \1'),
                (r'\n(\s*)struct ([\w_]+) \{', r'\n\1@objc class \2 : NSObject {'),
                ('struct ', 'class '),
                # ('^class ', 'public class '),
                ('mutating ', ''),
                ('  init\(\) \{\}', '  public override required init() {}'),
                # ('var unknownFields = ', 'public var unknownFields = '),
                # ('static let protoMessageName', 'public static let protoMessageName'),
                # ('static let _protobuf_nameMap', 'public static let _protobuf_nameMap'),
                # ('func decodeMessage<', 'public func decodeMessage<'),
                # ('func traverse<', 'public func traverse<'),
                # ('func _protobuf_generated_isEqualTo(', 'public func _protobuf_generated_isEqualTo('),
                )
            with open(swift_file_path, 'rt') as f:
                text = f.read()
            for before_pattern, after_pattern in patterns:
                # regex = re.compile()
                text = re.sub(before_pattern, after_pattern, text)
                # pattern_cmd = "sed -i '' 's/%s/%s/' '%s'" % (before_pattern, after_pattern, swift_file_path)
                # print '\t', pattern_cmd
                # commands.getoutput(pattern_cmd)
            with open(swift_file_path, 'wt') as f:
                f.write(text)
            # for before_pattern, after_pattern in patterns:
            #     pattern_cmd = "sed -i '' 's/%s/%s/' '%s'" % (before_pattern, after_pattern, swift_file_path)
            #     # print '\t', pattern_cmd
            #     commands.getoutput(pattern_cmd)
                    
            # process_if_appropriate(file_path)

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
